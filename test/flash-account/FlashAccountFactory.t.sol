// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

import {BaseLightAccountFactory} from "@flash-account/common/BaseLightAccountFactory.sol";
import {FlashAccount} from "@flash-account/FlashAccount.sol";
import {FlashAccountFactory} from "@flash-account/FlashAccountFactory.sol";

import {UpgradeableBeacon} from "../../contracts/1delta/flash-account//proxy/Beacon.sol";

contract FlashAccountFactoryTest is Test {
    using stdStorage for StdStorage;

    address public constant OWNER_ADDRESS = address(0x100);
    FlashAccountFactory public factory;
    EntryPoint public entryPoint;

    address public beaconOwner;
    address public initialAccountImplementation;
    UpgradeableBeacon public accountBeacon;

    function setUp() public {
        entryPoint = new EntryPoint();
        FlashAccount implementation = new FlashAccount(entryPoint);
        initialAccountImplementation = address(implementation);
        beaconOwner = address(this);
        accountBeacon = new UpgradeableBeacon(beaconOwner, initialAccountImplementation);
        factory = new FlashAccountFactory(address(this), address(accountBeacon), entryPoint);
    }

    function testReturnsAddressWhenAccountAlreadyExists() public {
        FlashAccount account = FlashAccount(payable(factory.createAccount(OWNER_ADDRESS, 1)));
        FlashAccount otherAccount = FlashAccount(payable(factory.createAccount(OWNER_ADDRESS, 1)));
        assertEq(address(account), address(otherAccount));
    }

    function testGetAddress() public {
        address counterfactual = factory.getAddress(OWNER_ADDRESS, 1);
        assertEq(counterfactual.codehash, bytes32(0));
        FlashAccount factual = FlashAccount(payable(factory.createAccount(OWNER_ADDRESS, 1)));
        assertTrue(address(factual).codehash != bytes32(0));
        assertEq(counterfactual, address(factual));
    }

    function testAddStake() public {
        assertEq(entryPoint.balanceOf(address(factory)), 0);
        vm.deal(address(this), 100 ether);
        factory.addStake{value: 10 ether}(10 hours, 10 ether);
        assertEq(entryPoint.getDepositInfo(address(factory)).stake, 10 ether);
    }

    function testUnlockStake() public {
        testAddStake();
        factory.unlockStake();
        assertEq(entryPoint.getDepositInfo(address(factory)).withdrawTime, block.timestamp + 10 hours);
    }

    function testWithdrawStake() public {
        testUnlockStake();
        vm.warp(10 hours);
        vm.expectRevert("Stake withdrawal is not due");
        factory.withdrawStake(payable(address(this)));
        assertEq(address(this).balance, 90 ether);
        vm.warp(10 hours + 1);
        factory.withdrawStake(payable(address(this)));
        assertEq(address(this).balance, 100 ether);
    }

    function testWithdrawStakeToZeroAddress() public {
        testUnlockStake();
        vm.expectRevert(BaseLightAccountFactory.ZeroAddressNotAllowed.selector);
        factory.withdrawStake(payable(address(0)));
    }

    function testWithdraw() public {
        factory.addStake{value: 10 ether}(10 hours, 1 ether);
        assertEq(address(factory).balance, 9 ether);
        factory.withdraw(payable(address(this)), address(0), 0); // amount = balance if native currency
        assertEq(address(factory).balance, 0);
    }

    function testWithdrawToZeroAddress() public {
        factory.addStake{value: 10 ether}(10 hours, 1 ether);
        vm.expectRevert(BaseLightAccountFactory.ZeroAddressNotAllowed.selector);
        factory.withdraw(payable(address(0)), address(0), 0);
    }

    function test2StepOwnershipTransfer() public {
        address owner1 = address(0x200);
        assertEq(factory.owner(), address(this));
        factory.transferOwnership(owner1);
        assertEq(factory.owner(), address(this));
        vm.prank(owner1);
        factory.acceptOwnership();
        assertEq(factory.owner(), owner1);
    }

    function testCannotRenounceOwnership() public {
        vm.expectRevert(BaseLightAccountFactory.InvalidAction.selector);
        factory.renounceOwnership();
    }

    function testRevertWithInvalidEntryPoint() public {
        IEntryPoint invalidEntryPoint = IEntryPoint(address(123));
        vm.expectRevert(abi.encodeWithSelector(BaseLightAccountFactory.InvalidEntryPoint.selector, (address(invalidEntryPoint))));
        new FlashAccountFactory(address(this), address(accountBeacon), invalidEntryPoint);
    }

    /// @dev Receive funds from withdraw.
    receive() external payable {}
}
