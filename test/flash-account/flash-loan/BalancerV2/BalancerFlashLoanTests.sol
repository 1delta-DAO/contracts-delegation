// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UpgradeableBeacon} from "../../../../contracts/1delta/flash-account//proxy/Beacon.sol";
import {BaseLightAccount} from "../../../../contracts/1delta/flash-account/common/BaseLightAccount.sol";
import {FlashAccount} from "../../../../contracts/1delta/flash-account/ethereum/FlashAccount.sol";
import {FlashAccountBase} from "../../../../contracts/1delta/flash-account/FlashAccountBase.sol";
import {FlashAccountFactory} from "../../../../contracts/1delta/flash-account/FlashAccountFactory.sol";

import {IVault} from "./interfaces/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanRecipient} from "./interfaces/IFlashLoanRecipient.sol";

import {Test} from "forge-std/Test.sol";

contract BalancerFlashLoanTests is Test {
    using MessageHashUtils for bytes32;

    uint256 public constant EOA_PRIVATE_KEY = 1;
    uint256 public constant BEACON_OWNER_PRIVATE_KEY = 2;
    address payable public constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));
    address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
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

    event FlashLoan(IFlashLoanRecipient indexed recipient, IERC20 indexed token, uint256 amount, uint256 feeAmount);

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

    function testBalancerV2FlashLoanWithUserOp() public {
        // the flashLoanFeePercentage for BalancerV2 is 0% so we're not concerned with fee calculations
        uint256 amountToBorrow = 1e9;

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = prepareUserOp(amountToBorrow, EOA_PRIVATE_KEY);

        vm.expectEmit(true, true, true, true);
        emit FlashLoan(IFlashLoanRecipient(address(account)), IERC20(USDC), amountToBorrow, 0);

        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function testBalancerV2FlashLoanDirect() public {
        // the flashLoanFeePercentage for BalancerV2 is 0% so we're not concerned with fee calculations
        uint256 amountToBorrow = 1e9;

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", BALANCER_VAULT, amountToBorrow);

        bytes memory params = abi.encode(dests, values, calls);

        // flash loan args
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(USDC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToBorrow;

        bytes memory flashLoanCall = abi.encodeWithSignature(
            "flashLoan(address,address[],uint256[],bytes)",
            address(account),
            tokens,
            amounts,
            params
        );

        vm.prank(eoaAddress);
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(IFlashLoanRecipient(address(account)), IERC20(USDC), amountToBorrow, 0);
        account.execute(BALANCER_VAULT, 0, flashLoanCall);
    }

    function _sign(uint256 privateKey, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function prepareUserOp(uint256 amountToBorrow, uint256 privateKey) private returns (PackedUserOperation memory op) {
        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", BALANCER_VAULT, amountToBorrow);

        bytes memory params = abi.encode(dests, values, calls);

        // flash loan args
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(USDC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToBorrow;

        bytes memory callData = abi.encodeWithSignature("flashLoan(address,address[],uint256[],bytes)", address(account), tokens, amounts, params);

        bytes memory executeCall = abi.encodeWithSignature("execute(address,uint256,bytes)", BALANCER_VAULT, 0, callData);
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
}
