// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UpgradeableBeacon} from "@flash-account/proxy/Beacon.sol";
import {BaseLightAccount} from "@flash-account/common/BaseLightAccount.sol";
import {FlashAccount} from "@flash-account/FlashAccount.sol";
import {FlashAccountBase} from "@flash-account/FlashAccountBase.sol";
import {FlashAccountFactory} from "@flash-account/FlashAccountFactory.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Test} from "forge-std/Test.sol";

contract MorphoFlashLoanTests is Test {
    using MessageHashUtils for bytes32;

    uint256 public constant EOA_PRIVATE_KEY = 1;
    uint256 public constant BEACON_OWNER_PRIVATE_KEY = 2;
    address payable public constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));
    address public constant MORPHO_POOL = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
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

    event FlashLoan(address indexed caller, address indexed token, uint256 assets);

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
        uint256 amountToBorrow = IERC20(USDC).balanceOf(address(MORPHO_POOL));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = prepareUserOp(amountToBorrow, EOA_PRIVATE_KEY);

        vm.expectEmit(true, true, true, false);
        emit FlashLoan(address(account), USDC, amountToBorrow);

        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function testBalancerV2FlashLoanDirect() public {
        // the flashLoanFeePercentage for BalancerV2 is 0% so we're not concerned with fee calculations
        uint256 amountToBorrow = IERC20(USDC).balanceOf(address(MORPHO_POOL));

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", MORPHO_POOL, amountToBorrow);

        bytes memory params = abi.encode(dests, values, calls);

        bytes memory flashLoanCall = abi.encodeWithSignature("flashLoan(address,uint256,bytes)", USDC, amountToBorrow, params);

        vm.prank(eoaAddress);
        vm.expectEmit(true, true, true, false);
        emit FlashLoan(address(account), USDC, amountToBorrow);
        account.execute(MORPHO_POOL, 0, flashLoanCall);
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
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", MORPHO_POOL, amountToBorrow);

        bytes memory params = abi.encode(dests, values, calls);

        bytes memory callData = abi.encodeWithSignature("flashLoan(address,uint256,bytes)", USDC, amountToBorrow, params);

        bytes memory executeCall = abi.encodeWithSignature("execute(address,uint256,bytes)", MORPHO_POOL, 0, callData);
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
