// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginCollateralSwapTest is DeltaSetup {
    address testUser = 0xcccccda06B44bcc94618620297Dc252EcfB56d85;

    uint256 DEFAULT_IR_MODE = 2; // variable

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 60500956, urlOrAlias: "https://rpc.ankr.com/mantle"});

        deployDelta();
        initializeDelta();
    }

    function test_margin_mantle_collateral_exact_in() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = 1;
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
        uint8 lenderId = 1;
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
        uint8 lenderId = 1;
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
        uint8 lenderId = 1;
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
}
