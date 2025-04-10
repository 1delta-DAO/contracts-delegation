// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdStyle} from "forge-std/StdStyle.sol";
import {console} from "forge-std/console.sol";
import {FlashAccountErc7579} from "contracts/1delta/flash-account/FlashAccountErc7579.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IPoolAddressesProvider} from "./interfaces/IPoolAddressesProvider.sol";
import "contracts/1delta/flash-account/utils/ModeLib.sol";
import {IEntryPoint, PackedUserOperation} from "./interfaces/IEntryPoint.sol";
import {INexusBootstrap, BootstrapConfig, IERC7484} from "./interfaces/INexusBootstrap.sol";
import {INexusFactory} from "./interfaces/INexusFactory.sol";
import {PercentageMath} from "./utils/PercentageMath.sol";

struct Execution {
    /// @notice The target address for the transaction
    address target;
    /// @notice The value in wei to send with the transaction
    uint256 value;
    /// @notice The calldata for the transaction
    bytes callData;
}

library ExecLib {
    function get2771CallData(bytes calldata cd) internal view returns (bytes memory callData) {
        /// @solidity memory-safe-assembly
        (cd);
        assembly {
            // as per solidity docs
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            callData := allocate(add(calldatasize(), 0x20)) //allocate extra 0x20 to store length
            mstore(callData, add(calldatasize(), 0x14)) //store length, extra 0x14 is for msg.sender address
            calldatacopy(add(callData, 0x20), 0, calldatasize())

            // The msg.sender address is shifted to the left by 12 bytes to remove the padding
            // Then the address without padding is stored right after the calldata
            let senderPtr := allocate(0x14)
            mstore(senderPtr, shl(96, caller()))
        }
    }

    function decodeBatch(bytes calldata callData) internal pure returns (Execution[] calldata executionBatch) {
        /*
         * Batch Call Calldata Layout
         * Offset (in bytes)    | Length (in bytes) | Contents
         * 0x0                  | 0x4               | bytes4 function selector
         * 0x4                  | -                 |
        abi.encode(IERC7579Execution.Execution[])
         */
        assembly ("memory-safe") {
            let dataPointer := add(callData.offset, calldataload(callData.offset))

            // Extract the ERC7579 Executions
            executionBatch.offset := add(dataPointer, 32)
            executionBatch.length := calldataload(dataPointer)
        }
    }

    function encodeBatch(Execution[] memory executions) internal pure returns (bytes memory callData) {
        callData = abi.encode(executions);
    }

    function decodeSingle(bytes calldata executionCalldata)
        internal
        pure
        returns (address target, uint256 value, bytes calldata callData)
    {
        target = address(bytes20(executionCalldata[0:20]));
        value = uint256(bytes32(executionCalldata[20:52]));
        callData = executionCalldata[52:];
    }

    function decodeDelegateCall(bytes calldata executionCalldata)
        internal
        pure
        returns (address delegate, bytes calldata callData)
    {
        // destructure executionCallData according to single exec
        delegate = address(uint160(bytes20(executionCalldata[0:20])));
        callData = executionCalldata[20:];
    }

    function encodeSingle(address target, uint256 value, bytes memory callData)
        internal
        pure
        returns (bytes memory userOpCalldata)
    {
        userOpCalldata = abi.encodePacked(target, value, callData);
    }
}

contract FlashAccountErc7579Test is Test {
    using MessageHashUtils for bytes32;

    event FlashLoan(
        address indexed target,
        address initiator,
        address indexed asset,
        uint256 amount,
        uint256 interestRateMode,
        uint256 premium,
        uint16 indexed referralCode
    );

    address public constant MAINNET_ENTRYPOINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address public constant NEXUS_BOOTSTRAP_ADDRESS = 0x879fa30248eeb693dcCE3eA94a743622170a3658;
    address public constant NEXUS_ACCOUNT_FACTORY_ADDRESS = 0x000000c3A93d2c5E02Cb053AC675665b1c4217F9;
    address public constant NEXUS_IMPLEMENTATION_ADDRESS = 0x000000aC74357BFEa72BBD0781833631F732cf19;
    address public constant NEXUS_K1_VALIDATOR_ADDRESS = 0x0000002D6DB27c52E3C11c1Cf24072004AC75cBa;
    address public constant NEXUS_K1_VALIDATOR_FACTORY_ADDRESS = 0x2828A0E0f36d8d8BeAE95F00E2BbF235e4230fAc;
    address public constant AAVE_POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Test user
    uint256 public constant PRIVATE_KEY = 0x1de17a;
    address public user;

    // Contracts
    FlashAccountErc7579 public module;
    IEntryPoint public entryPoint;
    IPool public aavePool;
    address public account;
    INexusBootstrap public bootstrap;
    INexusFactory public factory;

    function setUp() public {
        // Fork from a recent block to ensure all contracts are deployed
        vm.createSelectFork("https://ethereum.rpc.subquery.network/public");

        user = vm.addr(PRIVATE_KEY);
        vm.deal(user, 100 ether);

        entryPoint = IEntryPoint(payable(MAINNET_ENTRYPOINT_ADDRESS));
        module = new FlashAccountErc7579();
        aavePool = IPool(IPoolAddressesProvider(AAVE_POOL_ADDRESSES_PROVIDER).getPool());
        factory = INexusFactory(NEXUS_ACCOUNT_FACTORY_ADDRESS);

        bootstrap = INexusBootstrap(NEXUS_BOOTSTRAP_ADDRESS);

        _createAndSetupAccount();

        // print addresses
        console.log("--------------------------------");
        console.log(StdStyle.blue("account"), account);
        console.log(StdStyle.blue("module"), address(module));
        console.log(StdStyle.blue("aavePool"), address(aavePool));
        console.log("--------------------------------");
    }

    function test_flash_account_module_aave_v3_flash_loan() public {
        uint128 flashLoanPremiumTotal = aavePool.FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToBorrow = 1e9; // 1000 USDC
        uint256 aavePremium = PercentageMath.percentMul(amountToBorrow, flashLoanPremiumTotal);
        uint256 totalDebt = amountToBorrow + aavePremium;

        deal(USDC, address(account), aavePremium); // fund account with aave premium

        Execution[] memory repayExec = new Execution[](2);

        repayExec[0] = Execution({
            target: USDC,
            value: 0,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, address(module), aavePremium)
        });

        repayExec[1] = Execution({
            target: address(module),
            value: 0,
            callData: abi.encodeWithSelector(
                FlashAccountErc7579.handleRepay.selector,
                abi.encode(USDC, abi.encodeWithSelector(IERC20.approve.selector, address(aavePool), totalDebt))
            )
        });

        bytes memory repayCalldata = ExecLib.encodeBatch(repayExec);
        console.log("repayCalldata length", repayCalldata.length);
        console.logBytes(repayCalldata);

        bytes memory aaveFlashLoanCalldata = abi.encodeWithSelector(
            IPool.flashLoanSimple.selector,
            address(module),
            USDC,
            amountToBorrow,
            abi.encodePacked(ModeLib.encodeSimpleBatch(), repayCalldata),
            0
        );

        bytes memory flashloanCallData = abi.encodeWithSelector(
            FlashAccountErc7579.flashLoan.selector, address(aavePool), uint256(100), aaveFlashLoanCalldata
        );

        bytes memory execute = abi.encodeWithSignature(
            "execute(bytes32,bytes)",
            ModeLib.encodeSimpleSingle(),
            abi.encodePacked(address(module), uint256(0), flashloanCallData)
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({nounce: 1, calldata_: execute, initCode: ""});

        vm.prank(user);
        // vm.expectEmit(true, true, true, false);
        // emit FlashLoan(address(module), address(account), USDC, amountToBorrow, 0, aavePremium, 0);
        entryPoint.handleOps(ops, payable(address(0x1)));
    }

    function test_flash_account_module_eoa_flash_loan_reverts() public {
        uint256 amountToBorrow = 1000e6;

        bytes memory aaveFlashLoanCalldata = abi.encodeWithSelector(
            IPool.flashLoanSimple.selector,
            address(module),
            USDC,
            amountToBorrow,
            // the repay calldata is empty, because the module should revert before handling the flash loan
            abi.encodePacked(ModeLib.encodeSimpleBatch(), ""),
            0
        );

        // Create the call to the module
        bytes memory flashloanCallData = abi.encodeWithSelector(
            FlashAccountErc7579.flashLoan.selector, address(aavePool), uint256(100), aaveFlashLoanCalldata
        );

        // should revert
        vm.prank(user);
        vm.expectRevert(FlashAccountErc7579.NotInitialized.selector);
        (bool success,) = address(module).call(flashloanCallData);
    }

    function test_flash_account_module_installation() public {
        assertTrue(module.isInitialized(address(account)));
    }

    // ------------------------------------------------------------
    // Helper functions
    // ------------------------------------------------------------

    function _createAndSetupAccount() internal {
        // Create validator config
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({
            module: NEXUS_K1_VALIDATOR_ADDRESS,
            data: abi.encodePacked(user) // validator init data is the owner address
        });

        // Create executor config for flash loan module
        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({
            module: address(module),
            data: "" // empty initialization data
        });

        // Empty hook and fallbacks
        BootstrapConfig memory hook = BootstrapConfig({module: address(0), data: ""});
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);

        // Get initialization data from bootstrap
        bytes memory initData = bootstrap.getInitNexusCalldata(
            validators,
            executors,
            hook,
            fallbacks,
            IERC7484(address(0)), // no registry
            new address[](0), // no attesters
            0 // no threshold
        );

        bytes memory initCode = abi.encodePacked(
            address(factory), abi.encodeWithSelector(INexusFactory.createAccount.selector, initData, bytes32(0))
        );

        // get sender address
        (bool success, bytes memory data) = address(factory).staticcall(
            abi.encodeWithSelector(INexusFactory.computeAccountAddress.selector, initData, bytes32(0))
        );
        require(success, "Failed to get account address");
        account = abi.decode(data, (address));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({nounce: 0, calldata_: "", initCode: initCode});

        // Fund account BEFORE the operation
        vm.deal(address(account), 100 ether);

        // Execute the operation
        vm.prank(user);
        entryPoint.handleOps(ops, payable(user));
    }

    /**
     * @notice Creates a user operation with the given nounce and calldata
     * @param nounce The nounce for the user operation
     * @param calldata_ The calldata for the user operation
     * @return op The signed user operation
     */
    function _createUserOp(uint64 nounce, bytes memory calldata_, bytes memory initCode)
        internal
        returns (PackedUserOperation memory op)
    {
        uint128 verificationGasLimit = 2_000_000;
        uint128 callGasLimit = 2_000_000;
        uint128 maxPriorityFeePerGas = 1 gwei;
        uint128 maxFeePerGas = 100 gwei;

        op = PackedUserOperation({
            sender: account,
            nonce: _encodeNonce(NEXUS_K1_VALIDATOR_ADDRESS, uint64(nounce)),
            initCode: initCode,
            callData: calldata_,
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
            preVerificationGas: 500_000,
            gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
            paymasterAndData: "",
            signature: ""
        });
        op = _signUserOp(op);
    }

    function _encodeNonce(address validator_, uint64 nonce_) internal returns (uint256 nonce) {
        /**
         * Nonce structure
         *     [3 bytes empty][1 bytes validation mode][20 bytes validator][8 bytes nonce]
         */
        // Validation modes
        // bytes1 constant MODE_VALIDATION = 0x00;
        // bytes1 constant MODE_MODULE_ENABLE = 0x01;
        assembly {
            nonce := shl(64, validator_)
            let mode := shl(224, 0x0)
            nonce := or(nonce, mode)
            nonce := or(nonce, nonce_) // 8 bytes nounce
        }
    }

    function _signUserOp(PackedUserOperation memory op) internal returns (PackedUserOperation memory) {
        bytes32 userOpHash = entryPoint.getUserOpHash(op);
        bytes32 signHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, signHash);
        op.signature = abi.encodePacked(r, s, v);
        return op;
    }
}
