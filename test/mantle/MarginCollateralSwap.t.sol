// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginCollateralSwapTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_collateral_exact_in() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactInSingle(asset, assetTo, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.9499e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(14979803, balance, 1);
    }

    function test_margin_mantle_collateral_exact_in_multi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactInMulti(asset, assetTo, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.8499e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(14936349, balance, 1);
    }

    function test_margin_mantle_collateral_exact_out() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactOutSingle(asset, assetTo, lenderId);
        uint256 amountOut = 15.0e6;
        uint256 maximumIn = 15.05e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, maximumIn, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, maximumIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(15020225, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_collateral_exact_out_multi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactOutMulti(asset, assetTo, lenderId);
        uint256 amountOut = 15.0e6;
        uint256 maximumIn = 15.05e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, maximumIn, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, maximumIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(15032989, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_collateral_all_in() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactInSingle(asset, assetTo, lenderId);
        uint256 minimumOut = 39.9499e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapAllIn.selector, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, 1e20);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;

        // no collateral in left
        uint256 balanceFinal = IERC20All(collateralAsset).balanceOf(user);
        assertApproxEqAbs(balanceFinal, 0, 0);
        balanceFrom = balanceFrom - balanceFinal;

        //  swap 42 for approx 42
        assertApproxEqAbs(42163948, balanceFrom, 1);
        assertApproxEqAbs(42106566, balance, 1);
    }

    /** TEST FOR V2 CALLBACKS */

    function test_margin_mantle_collateral_exact_in_v2() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactInSingleV2(asset, assetTo, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.5499e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(14940398, balance, 1);
    }

    function test_margin_mantle_collateral_exact_in_multi_v2() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactInMultiV2(asset, assetTo, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.5499e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(14865356, balance, 1);
    }

    function test_margin_mantle_collateral_exact_out_v2() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactOutSingleV2(asset, assetTo, lenderId);
        uint256 amountOut = 15.0e6;
        uint256 maximumIn = 15.5e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, maximumIn, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, maximumIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(15059841, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_collateral_exact_out_multi_v2() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactOutMultiV2(asset, assetTo, lenderId);
        uint256 amountOut = 15.0e6;
        uint256 maximumIn = 15.5e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, maximumIn, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, maximumIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(15135887, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_collateral_all_in_v2() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCollateralSwapExactInSingleV2(asset, assetTo, lenderId);
        uint256 minimumOut = 39.9499e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapAllIn.selector, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, 1e20);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;

        // no collateral in left
        uint256 balanceFinal = IERC20All(collateralAsset).balanceOf(user);
        assertApproxEqAbs(balanceFinal, 0, 0);
        balanceFrom = balanceFrom - balanceFinal;

        //  swap 42 for approx 42
        assertApproxEqAbs(42163948, balanceFrom, 1);
        assertApproxEqAbs(41995030, balance, 1);
    }
}
