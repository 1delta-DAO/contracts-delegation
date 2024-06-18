// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginOpenTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_spot_exact_in_izi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = USDT;
        address assetOut = WMNT;

        deal(asset, user, 1e20);

        uint256 amountToSwap = 20.0e6;

        bytes memory swapPath = getSpotExactInSingle_izi(asset, assetOut);
        uint256 minimumOut = 13.0e18;

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToSwap);

        uint256 inBalance = IERC20All(asset).balanceOf(user);
        uint256 balance = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - IERC20All(asset).balanceOf(user);

        // deposit 10, recieve 13
        assertApproxEqAbs(amountToSwap, inBalance, 1);
        assertApproxEqAbs(13318419467531051937, balance, 1);
    }

    function test_margin_mantle_spot_exact_out_izi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = USDT;
        address assetOut = WMNT;

        deal(asset, user, 1e30);

        uint256 amountToSwap = 18.0e18;

        bytes memory swapPath = getSpotExactOutSingle_izi(asset, assetOut);
        uint256 maximumIn = 30.0e6;

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, maximumIn);

        uint256 inBalance = IERC20All(asset).balanceOf(user);
        uint256 balance = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToSwap, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - IERC20All(asset).balanceOf(user);

        // deposit 10, recieve 13
        assertApproxEqAbs(27030539, inBalance, 1);
        // izi can be unprecise
        assertApproxEqAbs(amountToSwap, balance, 1e7);
    }

    function test_margin_mantle_spot_exact_in_izi_reverted() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = WMNT;
        address assetOut = USDT;

        deal(asset, user, 1e20);

        uint256 amountToSwap = 20.0e18;

        bytes memory swapPath = getSpotExactInSingle_izi(asset, assetOut);
        uint256 minimumOut = 13.0e6;

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToSwap);

        uint256 inBalance = IERC20All(asset).balanceOf(user);
        uint256 balance = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - IERC20All(asset).balanceOf(user);

        // deposit 10, recieve 13
        assertApproxEqAbs(amountToSwap, inBalance, 100_000); // 100k = 1e-13
        assertApproxEqAbs(29850074, balance, 1);
    }

    function test_margin_mantle_spot_exact_out_izi_reverted() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = WMNT;
        address assetOut = USDT;

        deal(asset, user, 1e30);

        uint256 amountToSwap = 18.0e6;

        bytes memory swapPath = getSpotExactOutSingle_izi(asset, assetOut);
        uint256 maximumIn = 30.0e18;

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, maximumIn);

        uint256 inBalance = IERC20All(asset).balanceOf(user);
        uint256 balance = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToSwap, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - IERC20All(asset).balanceOf(user);

        // deposit 10, recieve 13
        assertApproxEqAbs(12059995241668815957, inBalance, 1);
        // izi can be unprecise
        assertApproxEqAbs(amountToSwap, balance, 1e7);
    }
}
