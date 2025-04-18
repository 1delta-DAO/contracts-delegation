// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract SweepTests is DeltaSetup {
    function test_mantle_sweep_fails() external {
        uint256 amount = 2112324324432;
        address user = testUser;
        address asset = TokensMantle.USDT;
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).transfer(brokerProxyAddress, amount);

        amount = IERC20All(asset).balanceOf(brokerProxyAddress);
        // some data
        bytes memory data = sweep(asset, testUser, amount + 1, SweepType.VALIDATE);
        // fails when too high
        vm.expectRevert(bytes4(0x7dd37f70)); // ("Slippage()");
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
    }

    function test_mantle_sweep_correct_when_zero() external {
        uint256 amount = 2112324324432;
        address user = testUser;
        address asset = TokensMantle.USDT;
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).transfer(brokerProxyAddress, amount);

        // some data
        bytes memory data = sweep(asset, testUser, amount, SweepType.VALIDATE);
        // sweep
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        // some data that should not error
        data = sweep(asset, testUser, 0, SweepType.VALIDATE);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
    }

    function test_mantle_sweep_works() external {
        uint256 amount = 2112324324432;
        address user = testUser;
        address asset = TokensMantle.USDT;
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).transfer(brokerProxyAddress, amount);

        // some data
        bytes memory data = sweep(asset, testUser, amount - 1, SweepType.VALIDATE);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
    }

    function test_mantle_sweep_works_balance() external {
        uint256 amount = 2112324324432;
        address user = testUser;
        address asset = TokensMantle.USDT;
        deal(asset, user, amount);

        amount = IERC20All(asset).balanceOf(user);

        vm.prank(user);
        IERC20All(asset).transfer(brokerProxyAddress, amount);

        // some data
        bytes memory data = sweep(asset, testUser, amount, SweepType.VALIDATE);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        assertApproxEqAbs(IERC20All(asset).balanceOf(user), amount, 0);
    }
}
