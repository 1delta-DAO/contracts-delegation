// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UpgradeableBeacon} from "../../../contracts/1delta/flash-account//proxy/Beacon.sol";
import {BaseLightAccount} from "../../../contracts/1delta/flash-account/common/BaseLightAccount.sol";
import {FlashAccount} from "../../../contracts/1delta/flash-account/FlashAccount.sol";
import {FlashAccountBase} from "../../../contracts/1delta/flash-account/FlashAccountBase.sol";
import {FlashAccountFactory} from "../../../contracts/1delta/flash-account/FlashAccountFactory.sol";
import {Owner} from "../FlashAccount.t.sol";

contract AaveFlashLoanTest is Test {
    using stdStorage for StdStorage;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 public constant EOA_PRIVATE_KEY = 1;
    uint256 public constant BEACON_OWNER_PRIVATE_KEY = 2;
    address payable public constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));
    address public constant AAVEV3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    bytes32 internal constant _MESSAGE_TYPEHASH = keccak256("LightAccountMessage(bytes message)");
    uint256 public mainnetFork;

    address public eoaAddress;
    address public beaconOwner;
    address public initialAccountImplementation;

    FlashAccount public account;
    FlashAccount public beaconOwnerAccount;
    EntryPoint public entryPoint;
    FlashAccountFactory public factory;

    UpgradeableBeacon public accountBeacon;

    Owner public contractOwner;

    function setUp() public {
        // Initialize a mainnet fork
        // string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        // mainnetFork = vm.createFork(rpcUrl);

        eoaAddress = vm.addr(EOA_PRIVATE_KEY);
        beaconOwner = vm.addr(BEACON_OWNER_PRIVATE_KEY);

        entryPoint = new EntryPoint();
        FlashAccount implementation = new FlashAccount(entryPoint);
        initialAccountImplementation = address(implementation);

        accountBeacon = new UpgradeableBeacon(beaconOwner, initialAccountImplementation);
        factory = new FlashAccountFactory(beaconOwner, address(accountBeacon), entryPoint);

        account = factory.createAccount(eoaAddress, 1);
        beaconOwnerAccount = factory.createAccount(beaconOwner, 1);

        vm.deal(address(account), 1 << 128);
        contractOwner = new Owner();
    }

    /**
     * function executeOperation(
     * address asset,
     * uint256 amount,
     * uint256 premium,
     * address initiator,
     * bytes calldata params
     *   )
     */
    function testCantCallexecuteOperationDirectly() public {
        //vm.prank(eoaAddress);
        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        account.executeOperation(USDC, 1000, 1, address(account), "");
    }
}
