// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {Test} from "forge-std/Test.sol";

// import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
// import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
// import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
// import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

// import {UpgradeableBeacon} from "@flash-account/proxy/Beacon.sol";
// import {BaseLightAccount} from "@flash-account/common/BaseLightAccount.sol";
// import {FlashAccountWithRegistry} from "@flash-account/FlashAccountWithRegistry.sol";
// import {FlashAccountBase} from "@flash-account/FlashAccountBase.sol";
// import {FlashAccountFactory} from "@flash-account/FlashAccountFactory.sol";
// import {LendingAdapterRegistry} from "@flash-account/LendingAdapterRegistry.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {CTokenSignatures} from "@flash-account/Lenders/Benqi/CTokenSignatures.sol";
// import {console2 as console} from "forge-std/console2.sol";
// import {Benqi} from "@flash-account/Lenders/Benqi/Benqi.sol";
// import {ILendingProvider} from "@flash-account/interfaces/ILendingProvider.sol";

// contract TestBenqi is Test, CTokenSignatures {
//     using MessageHashUtils for bytes32;

//     uint256 public constant EOA_PRIVATE_KEY = 1;
//     uint256 public constant BEACON_OWNER_PRIVATE_KEY = 2;
//     address payable public constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));

//     address public constant AAVEV3_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
//     address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

//     // address public constant BENQI_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;
//     address public constant qiUSDC = 0xB715808a78F6041E46d61Cb123C9B4A27056AE9C;
//     address public constant qiAVAX = 0x5C0401e81Bc07Ca70fAD469b451682c0d747Ef1c;

//     uint256 public chainFork;

//     address public eoaAddress;
//     address public beaconOwner;
//     address public initialAccountImplementation;

//     LendingAdapterRegistry public lendingAdapterRegistry;
//     Benqi public benqi;

//     FlashAccountWithRegistry public account;
//     FlashAccountWithRegistry public beaconOwnerAccount;
//     IEntryPoint public entryPoint;
//     FlashAccountFactory public factory;

//     UpgradeableBeacon public accountBeacon;

//     event Transfer(address indexed from, address indexed to, uint256 value);
//     event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
//     event RepayBorrow(address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows);
//     event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);
//     event AdapterRegistered(address indexed adapter, address indexed index);

//     function setUp() public {
//         // Initialize a mainnet fork
//         string memory rpcUrl = vm.envString("AVAX_RPC_URL");
//         chainFork = vm.createSelectFork(rpcUrl); // , 40840732);

//         eoaAddress = vm.addr(EOA_PRIVATE_KEY);
//         beaconOwner = vm.addr(BEACON_OWNER_PRIVATE_KEY);

//         vm.deal(eoaAddress, 1 << 128);
//         vm.prank(eoaAddress);
//         lendingAdapterRegistry = new LendingAdapterRegistry(); // the owner of the lending adapter registry is the eoa account

//         entryPoint = new EntryPoint();
//         FlashAccountWithRegistry implementation = new FlashAccountWithRegistry(entryPoint, address(lendingAdapterRegistry));
//         initialAccountImplementation = address(implementation);

//         accountBeacon = new UpgradeableBeacon(beaconOwner, initialAccountImplementation);
//         factory = new FlashAccountFactory(beaconOwner, address(accountBeacon), entryPoint);

//         account = FlashAccountWithRegistry(payable(factory.createAccount(eoaAddress, 1)));
//         beaconOwnerAccount = FlashAccountWithRegistry(payable(factory.createAccount(beaconOwner, 1)));

//         vm.deal(address(account), 1 << 128);

//         benqi = new Benqi();
//     }

//     function testRegisterBenqiAdapter() public {
//         address benqiComptroller = benqi.BENQI_COMPTROLLER();
//         vm.prank(eoaAddress);
//         vm.expectEmit(true, true, false, false);
//         emit AdapterRegistered(address(benqi), benqiComptroller);
//         lendingAdapterRegistry.registerAdapter(address(benqi), benqiComptroller);
//     }

//     function testGetbenqiAdapter() public {
//         address benqiComptroller = benqi.BENQI_COMPTROLLER();

//         vm.prank(eoaAddress);
//         lendingAdapterRegistry.registerAdapter(address(benqi), benqiComptroller);
//         address benqiAdapter = lendingAdapterRegistry.getAdapter(benqiComptroller);
//         assertEq(benqiAdapter, address(benqi));
//     }
// }
