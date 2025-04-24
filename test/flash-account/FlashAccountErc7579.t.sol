// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
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
import {FlashLoanLib, ExecLib, Execution} from "./utils/ModuleCalldatalib.sol";

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

    event UserOperationRevertReason(bytes32 indexed userOpHash, address indexed sender, uint256 nonce, bytes revertReason);

    address public constant MAINNET_ENTRYPOINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address public constant NEXUS_BOOTSTRAP_ADDRESS = 0x879fa30248eeb693dcCE3eA94a743622170a3658;
    address public constant NEXUS_ACCOUNT_FACTORY_ADDRESS = 0x000000c3A93d2c5E02Cb053AC675665b1c4217F9;
    address public constant NEXUS_IMPLEMENTATION_ADDRESS = 0x000000aC74357BFEa72BBD0781833631F732cf19;
    address public constant NEXUS_K1_VALIDATOR_ADDRESS = 0x0000002D6DB27c52E3C11c1Cf24072004AC75cBa;
    address public constant NEXUS_K1_VALIDATOR_FACTORY_ADDRESS = 0x2828A0E0f36d8d8BeAE95F00E2BbF235e4230fAc;
    address public constant AAVE_POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public constant BALANCER_V3_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant UNISWAP_V4_POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;

    bytes32 public constant IN_EXECUTION_SLOT = 0x12cfb2d397d8c322044bd0ecc925788f7eda447a6b3031394cf3b7c2f759f1b0;

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

        account = _createAndSetupAccount(user, PRIVATE_KEY);

        // print addresses
        // console.log("--------------------------------");
        // console.log(StdStyle.blue("account"), account);
        // console.log(StdStyle.blue("module"), address(module));
        // console.log(StdStyle.blue("aavePool"), address(aavePool));
        // console.log("--------------------------------");
    }

    function test_flash_account_module_aave_v3_flash_loan() public {
        uint128 flashLoanPremiumTotal = aavePool.FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToBorrow = 1e9; // 1000 USDC
        uint256 aavePremium = PercentageMath.percentMul(amountToBorrow, flashLoanPremiumTotal);
        uint256 totalDebt = amountToBorrow + aavePremium;

        deal(USDC, address(account), aavePremium); // fund account with aave premium

        // Create executions that will be executed after receiving the flash loan, here we only added one which transfers the amount to be repaid
        // but we could add more executions to be executed after the flash loan is received
        Execution[] memory repayExec = new Execution[](1);
        repayExec[0] = Execution({target: USDC, value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, address(module), totalDebt)});

        // Encode the repay execution batch
        bytes memory repayCalldata = ExecLib.encodeBatch(repayExec);

        // Create the flash loan calldata using FlashLoanLib
        bytes memory aaveFlashLoanCalldata = FlashLoanLib.createAaveV3SimpleFlashLoanCalldata(address(module), USDC, amountToBorrow, repayCalldata);

        // Create the execute calldata for the user operation
        bytes memory execute = FlashLoanLib.createFlashLoanExecute(address(module), address(aavePool), aaveFlashLoanCalldata);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({sender: account, privateKey: PRIVATE_KEY, nounce: 1, calldata_: execute, initCode: ""});

        vm.recordLogs();

        vm.prank(user);
        entryPoint.handleOps(ops, payable(address(0x1)));

        // Verify no revert was emitted
        assertFalse(_callReverted());
    }

    function test_flash_account_module_morpho_flash_loan() public {
        uint256 amountToBorrow = 1e9;

        uint256 totalDebt = amountToBorrow; // morpho has nko fee

        // list of transactions that should be executed after receiving the falsh loan, the last one should be a transfer
        // of the repay amount to the module, here we only have the transfer to module call
        Execution[] memory repayExec = new Execution[](1);
        repayExec[0] = Execution({target: USDC, value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, address(module), totalDebt)});

        // Encode the repay execution batch
        bytes memory repayCalldata = ExecLib.encodeBatch(repayExec);

        bytes memory morphoFlashLoanCalldata = FlashLoanLib.createMorphoFlashLoanCalldata(USDC, amountToBorrow, repayCalldata);

        bytes memory execute = FlashLoanLib.createFlashLoanExecute(address(module), MORPHO_BLUE, morphoFlashLoanCalldata);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({sender: account, privateKey: PRIVATE_KEY, nounce: 1, calldata_: execute, initCode: ""});

        vm.recordLogs();

        vm.prank(user);
        entryPoint.handleOps(ops, payable(address(0x1)));

        // Verify no revert was emitted
        assertFalse(_callReverted());
    }

    function test_flash_account_module_balancer_v2_flash_loan() public {
        uint256 amountToBorrow = 1e9;
        uint256 fee = 0.009e9;

        deal(USDC, address(account), fee); // funs account with fee amount
        uint256 totalDebt = amountToBorrow + fee;

        Execution[] memory repayExec = new Execution[](1);
        repayExec[0] = Execution({target: USDC, value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, address(module), totalDebt)});

        bytes memory repayCalldata = ExecLib.encodeBatch(repayExec);

        bytes memory balancerFlashLoanCalldata =
            FlashLoanLib.createBalancerV2SimpleFlashLoanCalldata(address(module), USDC, amountToBorrow, repayCalldata);

        bytes memory execute = FlashLoanLib.createFlashLoanExecute(address(module), BALANCER_V2_VAULT, balancerFlashLoanCalldata);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({sender: account, privateKey: PRIVATE_KEY, nounce: 1, calldata_: execute, initCode: ""});

        vm.recordLogs();

        vm.prank(user);
        entryPoint.handleOps(ops, payable(address(0x1)));

        // Verify no revert was emitted
        assertFalse(_callReverted());
    }

    function test_flash_account_module_balancer_v3_flash_loan() public {
        uint256 amountToBorrow = 1e9;
        uint256 totalDebt = amountToBorrow; // No fees

        Execution[] memory repayExec = new Execution[](1);
        repayExec[0] = Execution({target: USDC, value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, address(module), totalDebt)});

        bytes memory repayCalldata = ExecLib.encodeBatch(repayExec);

        bytes memory balancerV3FlashLoanCalldata =
            FlashLoanLib.createBalancerV3FlashLoanCalldata(address(module), USDC, amountToBorrow, repayCalldata);

        bytes memory execute = FlashLoanLib.createFlashLoanExecute(address(module), BALANCER_V3_VAULT, balancerV3FlashLoanCalldata);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({sender: account, privateKey: PRIVATE_KEY, nounce: 1, calldata_: execute, initCode: ""});

        vm.recordLogs();

        vm.prank(user);
        entryPoint.handleOps(ops, payable(address(0x1)));

        // Verify no revert was emitted
        assertFalse(_callReverted());
    }

    function test_flash_account_module_lock_is_cleared_after_flash_loan() public {
        test_flash_account_module_aave_v3_flash_loan();

        bytes32 inExecution = vm.load(address(module), IN_EXECUTION_SLOT);
        vm.assertEq(uint256(inExecution), type(uint256).max);
    }

    function test_flash_account_module_lock_is_cleared_after_morpho_flash_loan() public {
        test_flash_account_module_morpho_flash_loan();

        bytes32 inExecution = vm.load(address(module), IN_EXECUTION_SLOT);
        vm.assertEq(uint256(inExecution), type(uint256).max);
    }

    function test_flash_account_module_lock_is_cleared_after_balancer_v3_flash_loan() public {
        test_flash_account_module_balancer_v3_flash_loan();

        bytes32 inExecution = vm.load(address(module), IN_EXECUTION_SLOT);
        vm.assertEq(uint256(inExecution), type(uint256).max);
    }

    function test_flash_account_module_lock_is_cleared_after_balancer_v2_flash_loan() public {
        test_flash_account_module_balancer_v2_flash_loan();

        bytes32 inExecution = vm.load(address(module), IN_EXECUTION_SLOT);
        vm.assertEq(uint256(inExecution), type(uint256).max);
    }

    function test_flash_account_module_uniswap_v4_flash_loan() public {
        uint256 amountToBorrow = 1000e6;

        Execution[] memory repayExec = new Execution[](1);
        repayExec[0] =
            Execution({target: USDC, value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, address(module), amountToBorrow)});

        bytes memory repayCalldata = ExecLib.encodeBatch(repayExec);

        bytes memory uniswapV4FlashLoanCalldata = FlashLoanLib.createUniswapV4FlashLoanCalldata(USDC, amountToBorrow, repayCalldata);

        bytes memory execute = FlashLoanLib.createFlashLoanExecute(address(module), UNISWAP_V4_POOL_MANAGER, uniswapV4FlashLoanCalldata);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({sender: account, privateKey: PRIVATE_KEY, nounce: 1, calldata_: execute, initCode: ""});

        vm.recordLogs();

        vm.prank(user);
        entryPoint.handleOps(ops, payable(address(0x1)));

        // Verify no revert was emitted
        assertFalse(_callReverted());
    }

    function test_flash_account_module_lock_is_cleared_after_uniswap_v4_flash_loan() public {
        test_flash_account_module_uniswap_v4_flash_loan();

        bytes32 inExecution = vm.load(address(module), IN_EXECUTION_SLOT);
        vm.assertEq(uint256(inExecution), type(uint256).max);
    }

    function test_flash_account_module_eoa_flash_loan_reverts() public {
        uint256 amountToBorrow = 1000e6;

        // Create flash loan calldata using FlashLoanLib
        bytes memory aaveFlashLoanCalldata = FlashLoanLib.createAaveV3SimpleFlashLoanCalldata(
            address(module),
            USDC,
            amountToBorrow,
            "" // empty callback data, module should revert before this is used
        );

        // Create the call to the module's flashLoan function
        bytes memory flashloanCallData = abi.encodeWithSelector(FlashAccountErc7579.flashLoan.selector, address(aavePool), aaveFlashLoanCalldata);

        // Should revert when called directly by EOA
        vm.prank(user);
        vm.expectRevert(FlashAccountErc7579.NotInitialized.selector);
        (bool success,) = address(module).call(flashloanCallData);
        assertTrue(success);
    }

    function test_flash_account_module_uninitialized_account_reverts() public {
        // Create a new account that hasn't initialized the module
        uint256 pk = 0x123456;
        address user_ = vm.addr(pk);
        vm.deal(user_, 1 ether);

        // create smart account
        address acc_ = _createUninitializedAccount(user_, pk);

        // flash loan setup
        uint128 flashLoanPremiumTotal = aavePool.FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToBorrow = 1e9; // 1000 USDC
        uint256 aavePremium = PercentageMath.percentMul(amountToBorrow, flashLoanPremiumTotal);
        uint256 totalDebt = amountToBorrow + aavePremium;

        deal(USDC, address(acc_), aavePremium); // fund account with aave premium

        // Create transfer execution
        Execution[] memory repayExec = new Execution[](1);
        repayExec[0] = Execution({target: USDC, value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, address(module), totalDebt)});

        bytes memory repayCalldata = ExecLib.encodeBatch(repayExec);

        // Create the flash loan calldata using FlashLoanLib
        bytes memory aaveFlashLoanCalldata = FlashLoanLib.createAaveV3SimpleFlashLoanCalldata(address(module), USDC, amountToBorrow, repayCalldata);

        // Create the execute calldata for the user operation
        bytes memory execute = FlashLoanLib.createFlashLoanExecute(address(module), address(aavePool), aaveFlashLoanCalldata);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({sender: acc_, privateKey: pk, nounce: 1, calldata_: execute, initCode: ""});

        vm.recordLogs();

        vm.prank(user_);
        entryPoint.handleOps(ops, payable(address(0x1)));

        // we check the latest revert reason, so it is possible for the call to revert for other reasons too
        // in this test, it only reverts once with the NotInitialized error
        (bool reverted, bytes4 revertReason) = _getRevertReason(entryPoint.getUserOpHash(ops[0]));
        assertTrue(reverted); // should revert
        assertEq(revertReason, bytes4(keccak256("NotInitialized()")));
    }

    function test_flash_account_module_installation() public view {
        assertTrue(module.isInitialized(address(account)));
    }

    function test_flash_account_module_not_initialized() public view {
        assertFalse(module.isInitialized(address(0xdeadadd)));
    }

    function test_flash_account_module_attack_malicious_call_reverts() public {
        // Attacker address
        uint256 attackerPk = 0xa77ac;
        address attacker = vm.addr(attackerPk);
        vm.deal(attacker, 1 ether);
        // create the attacker account
        address attackerAccount = _createAndSetupAccount(attacker, attackerPk);

        deal(USDC, attackerAccount, 1e6);

        bytes memory maliciousData = abi.encodeWithSelector(
            IPool.flashLoanSimple.selector,
            address(module),
            USDC,
            1e6, // Small amount
            new bytes(1 << 10), // random data
            0
        );

        // Create the execute calldata for the user operation
        bytes memory execute = FlashLoanLib.createFlashLoanExecute(
            address(module),
            address(0x100), // using invalid flash loan provider
            maliciousData
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({sender: attackerAccount, privateKey: attackerPk, nounce: 1, calldata_: execute, initCode: ""});

        vm.prank(attacker);
        entryPoint.handleOps(ops, payable(address(0x1)));

        // load the execution lock storage slot
        bytes32 inExecution = vm.load(address(module), IN_EXECUTION_SLOT);
        vm.assertEq(uint256(inExecution), type(uint256).max); // not in execution
    }

    // ------------------------------------------------------------
    // Helper functions
    // ------------------------------------------------------------

    function _createAndSetupAccount(address user_, uint256 pk) internal returns (address) {
        // Create validator config
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({
            module: NEXUS_K1_VALIDATOR_ADDRESS,
            data: abi.encodePacked(user_) // validator init data is the owner address
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

        bytes memory initCode = abi.encodePacked(address(factory), abi.encodeWithSelector(INexusFactory.createAccount.selector, initData, bytes32(0)));

        // get sender address
        (bool success, bytes memory data) =
            address(factory).staticcall(abi.encodeWithSelector(INexusFactory.computeAccountAddress.selector, initData, bytes32(0)));
        require(success, "Failed to get account address");
        address account_ = abi.decode(data, (address));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({sender: account_, privateKey: pk, nounce: 0, calldata_: "", initCode: initCode});

        // Fund account BEFORE the operation
        vm.deal(address(account_), 100 ether);

        // Execute the operation
        vm.prank(user_);
        entryPoint.handleOps(ops, payable(user_));

        return account_;
    }

    function _createUninitializedAccount(address user_, uint256 pk) internal returns (address) {
        // Create validator config
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({
            module: NEXUS_K1_VALIDATOR_ADDRESS,
            data: abi.encodePacked(user_) // validator init data is the owner address
        });

        // Create executor config
        BootstrapConfig[] memory executors = new BootstrapConfig[](0);

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

        bytes memory initCode = abi.encodePacked(address(factory), abi.encodeWithSelector(INexusFactory.createAccount.selector, initData, bytes32(0)));

        // get sender address
        (bool success, bytes memory data) =
            address(factory).staticcall(abi.encodeWithSelector(INexusFactory.computeAccountAddress.selector, initData, bytes32(0)));
        require(success, "Failed to get account address");
        address account_ = abi.decode(data, (address));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp({sender: account_, privateKey: pk, nounce: 0, calldata_: "", initCode: initCode});

        // Fund account BEFORE the operation
        vm.deal(address(account_), 100 ether);

        // record logs
        vm.recordLogs();

        // Execute the operation
        vm.prank(user_);
        entryPoint.handleOps(ops, payable(user_));

        (bool reverted,) = _getRevertReason(entryPoint.getUserOpHash(ops[0]));
        assertFalse(reverted); // should not revert

        return account_;
    }

    /**
     * @notice Creates a user operation with the given nounce and calldata
     * @param nounce The nounce for the user operation
     * @param calldata_ The calldata for the user operation
     * @return op The signed user operation
     */
    function _createUserOp(
        address sender,
        uint256 privateKey,
        uint64 nounce,
        bytes memory calldata_,
        bytes memory initCode
    )
        internal
        view
        returns (PackedUserOperation memory op)
    {
        uint128 verificationGasLimit = 2_000_000;
        uint128 callGasLimit = 2_000_000;
        uint128 maxPriorityFeePerGas = 1 gwei;
        uint128 maxFeePerGas = 100 gwei;

        op = PackedUserOperation({
            sender: sender,
            nonce: _encodeNonce(NEXUS_K1_VALIDATOR_ADDRESS, uint64(nounce)),
            initCode: initCode,
            callData: calldata_,
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
            preVerificationGas: 500_000,
            gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
            paymasterAndData: "",
            signature: ""
        });
        op = _signUserOp(op, privateKey);
    }

    function _encodeNonce(address validator_, uint64 nonce_) internal pure returns (uint256 nonce) {
        assembly {
            /**
             * Nonce structure
             *     [3 bytes empty][1 bytes validation mode][20 bytes validator][8 bytes nonce]
             */
            // Validation modes
            // bytes1 constant MODE_VALIDATION = 0x00;
            // bytes1 constant MODE_MODULE_ENABLE = 0x01;
            nonce := shl(64, validator_)
            let mode := shl(224, 0x0)
            nonce := or(nonce, mode)
            nonce := or(nonce, nonce_) // 8 bytes nounce
        }
    }

    function _signUserOp(PackedUserOperation memory op, uint256 privateKey) internal view returns (PackedUserOperation memory) {
        bytes32 userOpHash = entryPoint.getUserOpHash(op);
        bytes32 signHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, signHash);
        op.signature = abi.encodePacked(r, s, v);
        return op;
    }

    function _getRevertReason(bytes32 userOpHash) internal returns (bool reverted, bytes4 revertReason) {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 eventSignature = keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)");

        for (uint256 i = entries.length - 1; i != 0; i--) {
            // find the latest revert reason
            if (entries[i].topics[0] == eventSignature) {
                if (entries[i].topics[1] == userOpHash) {
                    reverted = true;
                    (,,, revertReason) = abi.decode(entries[i].data, (bytes32, bytes32, bytes32, bytes4));
                    break;
                }
            }
        }

        return (reverted, revertReason);
    }

    function _callReverted() internal returns (bool) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)");

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                return true;
            }
        }
        return false;
    }
}
