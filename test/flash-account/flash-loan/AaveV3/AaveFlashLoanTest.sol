// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UpgradeableBeacon} from "@flash-account/proxy/Beacon.sol";
import {BaseLightAccount} from "@flash-account/common/BaseLightAccount.sol";
import {FlashAccount} from "@flash-account/FlashAccount.sol";
import {FlashAccountBase} from "@flash-account/FlashAccountBase.sol";
import {FlashAccountFactory} from "@flash-account/FlashAccountFactory.sol";

import {IPool, DataTypes} from "./interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AaveFlashLoanTest is Test {
    using MessageHashUtils for bytes32;

    uint256 public constant EOA_PRIVATE_KEY = 1;
    uint256 public constant BEACON_OWNER_PRIVATE_KEY = 2;
    address payable public constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));
    address public constant AAVEV3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 public mainnetFork;

    address public eoaAddress;
    address public beaconOwner;
    address public initialAccountImplementation;

    FlashAccount public account;
    FlashAccount public beaconOwnerAccount;
    EntryPoint public entryPoint;
    FlashAccountFactory public factory;

    UpgradeableBeacon public accountBeacon;

    event FlashLoan(
        address indexed target,
        address initiator,
        address indexed asset,
        uint256 amount,
        DataTypes.InterestRateMode interestRateMode,
        uint256 premium,
        uint16 indexed referralCode
    );

    function setUp() public {
        // Initialize a mainnet fork
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createSelectFork(rpcUrl);

        eoaAddress = vm.addr(EOA_PRIVATE_KEY);
        beaconOwner = vm.addr(BEACON_OWNER_PRIVATE_KEY);

        entryPoint = new EntryPoint();
        FlashAccount implementation = new FlashAccount(entryPoint);
        initialAccountImplementation = address(implementation);

        accountBeacon = new UpgradeableBeacon(beaconOwner, initialAccountImplementation);
        factory = new FlashAccountFactory(beaconOwner, address(accountBeacon), entryPoint);

        account = FlashAccount(payable(factory.createAccount(eoaAddress, 1)));
        beaconOwnerAccount = FlashAccount(payable(factory.createAccount(beaconOwner, 1)));

        vm.deal(address(account), 1 << 128);
        vm.deal(eoaAddress, 1 << 128);
    }

    function testRevertIfNotInExecution() public {
        address sender = address(0x0a1);
        vm.deal(sender, 1e6);

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", sender, 1e6);

        bytes memory params = abi.encode(dests, values, calls);

        vm.prank(sender);
        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        account.executeOperation(USDC, 1e9, 0, 0x120D2fDdC53467479570B2E7870d6d7A80b0f050, params);
    }

    function testRevertIfDirectlyCallPoolForLoan() public {
        address[] memory dests = new address[](1);
        dests[0] = USDC;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", address(this), 1e6);
        bytes memory params = abi.encode(dests, values, calls);

        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        IPool(AAVEV3_POOL).flashLoanSimple(address(account), USDC, 1e9, params, 0);
    }

    function testAaveV3FlashLoanDirect() public {
        uint128 flashLoanPremiumTotal = IPool(AAVEV3_POOL).FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToBorrow = 1e9;
        uint256 aavePremium = percentMul(amountToBorrow, flashLoanPremiumTotal);
        uint256 totalDebt = amountToBorrow + aavePremium;

        // transfer USDC to account
        vm.prank(0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341);
        IERC20(USDC).transfer(address(account), aavePremium);

        console.log("totalDebt", totalDebt);

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", AAVEV3_POOL, totalDebt);

        bytes memory params = abi.encode(dests, values, calls);

        bytes memory flashLoanCall = abi.encodeWithSignature(
            "flashLoanSimple(address,address,uint256,bytes,uint16)",
            address(account),
            USDC,
            amountToBorrow,
            params,
            0
        );

        vm.prank(eoaAddress);
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(address(account), address(account), USDC, amountToBorrow, DataTypes.InterestRateMode.NONE, aavePremium, uint16(0));
        account.execute(AAVEV3_POOL, 0, flashLoanCall);
    }

    function testExploitDecodeAndExecuteReverts() public {
        address exploiter = vm.addr(uint256(keccak256("exploiter")));
        uint128 flashLoanPremiumTotal = IPool(AAVEV3_POOL).FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToBorrow = 1e9;
        uint256 aavePremium = percentMul(amountToBorrow, flashLoanPremiumTotal);
        uint256 totalDebt = amountToBorrow + aavePremium;

        // transfer USDC to account
        vm.prank(0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341);
        IERC20(USDC).transfer(address(account), aavePremium + 1e9);

        console.log("totalDebt", totalDebt);

        address[] memory dests = new address[](2);
        dests[0] = USDC;
        dests[1] = USDC;

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", AAVEV3_POOL, totalDebt);
        calls[1] = abi.encodeWithSignature("transfer(address,uint256)", exploiter, 1e9);

        bytes memory params = abi.encode(dests, values, calls);

        vm.prank(exploiter);
        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        AAVEV3_POOL.call(
            abi.encodeWithSignature("flashLoanSimple(address,address,uint256,bytes,uint16)", address(account), USDC, amountToBorrow, params, 0)
        );
    }

    function testAaveV3FlashLoanWithUserOp() public {
        uint128 flashLoanPremiumTotal = IPool(AAVEV3_POOL).FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToBorrow = 1e9;
        uint256 aavePremium = percentMul(amountToBorrow, flashLoanPremiumTotal);
        uint256 totalDebt = amountToBorrow + aavePremium;

        // Transfer USDC to account
        vm.prank(0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341);
        IERC20(USDC).transfer(address(account), aavePremium);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = prepareUserOp(amountToBorrow, totalDebt, EOA_PRIVATE_KEY);

        vm.expectEmit(true, true, true, true);
        emit FlashLoan(address(account), address(account), USDC, amountToBorrow, DataTypes.InterestRateMode.NONE, aavePremium, uint16(0));

        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function _sign(uint256 privateKey, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function prepareUserOp(uint256 amountToBorrow, uint256 totalDebt, uint256 privateKey) private returns (PackedUserOperation memory op) {
        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", AAVEV3_POOL, totalDebt);

        bytes memory params = abi.encode(dests, values, calls);

        bytes memory callData = abi.encodeWithSignature(
            "flashLoanSimple(address,address,uint256,bytes,uint16)",
            address(account),
            USDC,
            amountToBorrow,
            params,
            0
        );

        bytes memory executeCall = abi.encodeWithSignature("execute(address,uint256,bytes)", AAVEV3_POOL, 0, callData);
        op = _getUnsignedOp(executeCall);
        op.signature = abi.encodePacked(BaseLightAccount.SignatureType.EOA, _sign(privateKey, entryPoint.getUserOpHash(op).toEthSignedMessageHash()));
    }

    function _getUnsignedOp(bytes memory callData) internal view returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 1 << 24;
        uint128 callGasLimit = 1 << 24;
        uint128 maxPriorityFeePerGas = 1 << 8;
        uint128 maxFeePerGas = 1 << 8;
        return
            PackedUserOperation({
                sender: address(account),
                nonce: entryPoint.getNonce(address(account), 0),
                initCode: "",
                callData: callData,
                accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
                preVerificationGas: 1 << 24,
                gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
                paymasterAndData: "",
                signature: ""
            });
    }

    // Maximum percentage factor (100.00%)
    uint256 internal constant PERCENTAGE_FACTOR = 1e4;

    // Half percentage factor (50.00%)
    uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

    /**
     * @notice Executes a percentage multiplication
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param value The value of which the percentage needs to be calculated
     * @param percentage The percentage of the value to be calculated
     * @return result value percentmul percentage
     */
    function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
        assembly {
            if iszero(or(iszero(percentage), iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage))))) {
                revert(0, 0)
            }

            result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
        }
    }
}
