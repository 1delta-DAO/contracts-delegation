// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UpgradeableBeacon} from "../../../contracts/1delta/flash-account/proxy/Beacon.sol";
import {BaseLightAccount} from "../../../contracts/1delta/flash-account/common/BaseLightAccount.sol";
import {FlashAccount} from "../../../contracts/1delta/flash-account/avalanche/FlashAccount.sol";
import {FlashAccountBase} from "../../../contracts/1delta/flash-account/FlashAccountBase.sol";
import {FlashAccountFactory} from "../../../contracts/1delta/flash-account/FlashAccountFactory.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CTokenSignatures} from "../../../contracts/1delta/flash-account/avalanche/lendingProviders/Benqi/CTokenSignatures.sol";
import {console2 as console} from "forge-std/console2.sol";

contract TestBenqi is Test, CTokenSignatures {
    using MessageHashUtils for bytes32;

    uint256 public constant EOA_PRIVATE_KEY = 1;
    uint256 public constant BEACON_OWNER_PRIVATE_KEY = 2;
    address payable public constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));

    address public constant AAVEV3_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    address public constant BENQI_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;
    address public constant qiUSDC = 0xB715808a78F6041E46d61Cb123C9B4A27056AE9C;
    address public constant qiAVAX = 0x5C0401e81Bc07Ca70fAD469b451682c0d747Ef1c;

    uint256 public chainFork;

    address public eoaAddress;
    address public beaconOwner;
    address public initialAccountImplementation;

    FlashAccount public account;
    FlashAccount public beaconOwnerAccount;
    IEntryPoint public entryPoint;
    FlashAccountFactory public factory;

    UpgradeableBeacon public accountBeacon;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
    event RepayBorrow(address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows);
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);

    function setUp() public {
        // Initialize a mainnet fork
        string memory rpcUrl = vm.envString("AVAX_RPC_URL");
        chainFork = vm.createSelectFork(rpcUrl); // , 40840732);

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

    function testSupply() public {
        _supplyUsdc(1e9);
    }

    function testWithdraw() public {
        _supplyUsdc(1e9);
        _withdrawUsdc(1e9);
    }

    function testWithdrawAll() public {
        _supplyUsdc(1e9);
        vm.warp(block.timestamp + 10000);
        (bool success, bytes memory data) = qiUSDC.call(abi.encodeWithSelector(CTOKEN_BALANCE_OF_UNDERLYING_SELECTOR, address(account)));
        uint256 balance = abi.decode(data, (uint256));
        _withdrawUsdc(balance);
        vm.assertGt(balance, 1e9);
        // console.log("balance", balance);
    }

    function testBorrow() public {
        // lend some usdc to qiUSDC
        _supplyUsdc(1e9);
        // borrow usdc from qiUSDC
        _borrowUsdc(1e8);
    }

    function testRepay() public {
        // lend some usdc to qiUSDC
        _supplyUsdc(1e9);
        // borrow usdc from qiUSDC
        _borrowUsdc(1e8);
        // repay usdc to qiUSDC
        _repayUsdc(1e8);
    }

    function _supplyUsdc(uint256 amount) private {
        vm.prank(0x4aeFa39caEAdD662aE31ab0CE7c8C2c9c0a013E8);
        USDC.call(abi.encodeWithSignature("transfer(address,uint256)", address(account), amount));
        vm.startPrank(eoaAddress);
        // approve Token
        USDC.call(abi.encodeWithSignature("approve(address,uint256)", qiUSDC, amount));
        // lend to Benqi
        vm.expectEmit(true, true, false, false);
        emit Transfer(qiUSDC, address(account), 0);
        account.benqiSupply(qiUSDC, amount);
        vm.stopPrank();
    }

    function _borrowUsdc(uint256 amount) private {
        vm.startPrank(eoaAddress);
        vm.expectEmit(true, true, false, false);
        emit Borrow(address(account), amount, 0, 0);
        account.benqiBorrow(qiUSDC, amount);
        vm.stopPrank();
    }

    function _repayUsdc(uint256 amount) private {
        vm.startPrank(eoaAddress);
        vm.expectEmit(true, true, false, false);
        emit RepayBorrow(address(account), address(account), amount, 0, 0);
        account.benqiRepay(qiUSDC, amount);
        vm.stopPrank();
    }

    function _withdrawUsdc(uint256 amount) private {
        vm.startPrank(eoaAddress);
        vm.expectEmit(true, true, false, false);
        emit Redeem(address(account), amount, 0);
        account.benqiWithdrawUnderlying(qiUSDC, amount);
        vm.stopPrank();
    }
}
