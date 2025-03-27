// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {FlashAccountErc7579} from "../../contracts/1delta/flash-account/FlashAccountErc7579.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/core/UserOperationLib.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "aave-v3-core/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {NexusBootstrap, BootstrapConfig} from "nexus/contracts/utils/NexusBootstrap.sol";
import {IERC7484} from "nexus/contracts/interfaces/IERC7484.sol";
import {K1Validator} from "nexus/contracts/modules/validators/K1Validator.sol";
import {NexusAccountFactory} from "nexus/contracts/factory/NexusAccountFactory.sol";
import {Nexus} from "nexus/contracts/Nexus.sol";
import "nexus/contracts/lib/ModeLib.sol"; // ModeLib and types for execution mode
import {PercentageMath} from "aave-v3-core/protocol/libraries/math/PercentageMath.sol";
import {ExecLib} from "nexus/contracts/lib/ExecLib.sol";
import {Execution} from "nexus/contracts/types/DataTypes.sol";

contract FlashAccountErc7579Test is Test {
    using MessageHashUtils for bytes32;

    address public constant MAINNET_ENTRYPOINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address public constant AAVE_POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Test user
    uint256 public constant PRIVATE_KEY = 0x1de17a;
    address public user;

    // Contracts
    FlashAccountErc7579 public module;
    EntryPoint public entryPoint;
    IPool public aavePool;
    address public account;
    NexusBootstrap public bootstrap;
    // MockValidator public validator;
    K1Validator public validator;
    NexusAccountFactory public factory;
    Nexus public implementation;

    function setUp() public {
        // Fork from a recent block to ensure all contracts are deployed
        vm.createSelectFork("https://ethereum.rpc.subquery.network/public");

        user = vm.addr(PRIVATE_KEY);
        vm.deal(user, 100 ether);

        entryPoint = EntryPoint(payable(MAINNET_ENTRYPOINT_ADDRESS));
        module = new FlashAccountErc7579();
        aavePool = IPool(IPoolAddressesProvider(AAVE_POOL_ADDRESSES_PROVIDER).getPool());
        // validator = new MockValidator();
        validator = new K1Validator();
        implementation = new Nexus(MAINNET_ENTRYPOINT_ADDRESS);
        factory = new NexusAccountFactory(address(implementation), user);

        bootstrap = new NexusBootstrap();

        _createAndSetupAccount();
    }

    function testFlashLoanOnAave() public {
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
        entryPoint.handleOps(ops, payable(address(0x1)));
    }

    function testModuleInstallation() public {
        assertTrue(module.isInitialized(address(account)));
    }

    function _createAndSetupAccount() internal {
        // Create validator config
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({
            module: address(validator),
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
            address(factory), abi.encodeWithSelector(NexusAccountFactory.createAccount.selector, initData, bytes32(0))
        );

        // get sender address
        (bool success, bytes memory data) = address(factory).staticcall(
            abi.encodeWithSelector(NexusAccountFactory.computeAccountAddress.selector, initData, bytes32(0))
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
        // Fund account
        vm.deal(address(account), 100 ether);
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
            nonce: _encodeNonce(address(validator), uint64(nounce)),
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

    function _encodeNonce(address validator_, uint64 nounce_) internal returns (uint256 nounce) {
        /**
         * Nonce structure
         *     [3 bytes empty][1 bytes validation mode][20 bytes validator][8 bytes nonce]
         */
        // Validation modes
        // bytes1 constant MODE_VALIDATION = 0x00;
        // bytes1 constant MODE_MODULE_ENABLE = 0x01;
        assembly {
            nounce := shl(64, validator_)
            let mode := shl(224, 0x0)
            nounce := or(nounce, mode)
            nounce := or(nounce, nounce_) // 8 bytes nounce
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
