// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract TransfersTest is DeltaSetup {
    address otherUser = 0x3e8E36AC89A038b5b992499f8E94922E9c76E013;

    function test_mantle_transfers_wrap() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        vm.deal(user, 10 ether);

        uint256 amountToTransfer = 1.0e18;

        address wrappedNative = WMNT;

        uint256 balanceBefore = IERC20All(wrappedNative).balanceOf(brokerProxyAddress);
        vm.prank(user);
        ILending(brokerProxyAddress).wrap{value: amountToTransfer}();

        uint256 balance = IERC20All(wrappedNative).balanceOf(brokerProxyAddress);
        assertApproxEqAbs(balance - balanceBefore, amountToTransfer, 0);
    }

    function test_mantle_transfers_wrap_to() external /** address user, uint8 lenderId */ {
        address user = testUser;
        address recipient = otherUser;
        vm.assume(user != address(0));

        vm.deal(user, 10 ether);

        uint256 amountToTransfer = 1.0e18;

        address wrappedNative = WMNT;

        uint256 balanceBefore = IERC20All(wrappedNative).balanceOf(recipient);
        vm.prank(user);
        ILending(brokerProxyAddress).wrapTo{value: amountToTransfer}(recipient);

        uint256 balance = IERC20All(wrappedNative).balanceOf(recipient);
        assertApproxEqAbs(balance - balanceBefore, amountToTransfer, 0);
    }

    function test_mantle_transfers_unwrap() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        vm.deal(user, 10 ether);

        uint256 amountToTransfer = 1.0e18;

        vm.prank(user);
        ILending(brokerProxyAddress).wrap{value: amountToTransfer}();

        uint256 nativeBefore = payable(user).balance;
        vm.prank(user);
        ILending(brokerProxyAddress).unwrap();

        uint256 nativeAfter = payable(user).balance;

        assertApproxEqAbs(nativeAfter - nativeBefore, amountToTransfer, 0);
    }

    function test_mantle_transfers_unwrap_to() external /** address user, uint8 lenderId */ {
        address user = testUser;
        address payable recipient = payable(otherUser);
        vm.assume(user != address(0));

        vm.deal(user, 10 ether);

        uint256 amountToTransfer = 1.0e18;

        vm.prank(user);
        ILending(brokerProxyAddress).wrap{value: amountToTransfer}();

        uint256 nativeBefore = recipient.balance;
        vm.prank(user);
        ILending(brokerProxyAddress).unwrapTo(recipient);

        uint256 nativeAfter = recipient.balance;

        assertApproxEqAbs(nativeAfter - nativeBefore, amountToTransfer, 0);
    }
}
