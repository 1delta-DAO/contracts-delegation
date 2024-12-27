// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginCollateralSwapTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_collateral_exact_in(uint16 lenderId) external /** address user, uint16 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactInSingle(asset, assetTo, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.9499e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(14984996, balance, 1);
    }

    function test_margin_mantle_collateral_exact_in_multi(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactInMulti(asset, assetTo, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.8499e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(14945822, balance, 1);
    }

    function test_margin_mantle_collateral_exact_out(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactOutSingle(asset, assetTo, lenderId);
        uint256 amountOut = 15.0e6;
        uint256 maximumIn = 15.05e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, maximumIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            amountOut, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(15015019, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_collateral_exact_out_multi(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactOutMulti(asset, assetTo, lenderId);
        uint256 amountOut = 15.0e6;
        uint256 maximumIn = 15.55e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, maximumIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            amountOut, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(15392723, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_collateral_all_in(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactInSingle(asset, assetTo, lenderId);
        uint256 minimumOut = 29.9499e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, 1e20);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            0, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;

        // no collateral in left
        uint256 balanceFinal = IERC20All(collateralAsset).balanceOf(user);
        assertApproxEqAbs(balanceFinal, 0, 0);
        balanceFrom = balanceFrom - balanceFinal;

        //  swap 42 for approx 42
        assertApproxEqAbs(39122533, balanceFrom, 1);
        assertApproxEqAbs(39083106, balance, 1);
    }

    /** TEST FOR V2 CALLBACKS */

    function test_margin_mantle_collateral_exact_in_v2(uint16 lenderId) external /** address user, uint16 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactInSingleV2(asset, assetTo, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.5499e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(14909728, balance, 1);
    }

    function test_margin_mantle_collateral_exact_in_multi_v2(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactInMultiV2(asset, assetTo, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.5499e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(14884120, balance, 1);
    }

    function test_margin_mantle_collateral_exact_out_v2(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactOutSingleV2(asset, assetTo, lenderId);
        uint256 amountOut = 15.0e6;
        uint256 maximumIn = 15.5e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, maximumIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            amountOut, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(15090822, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_collateral_exact_out_multi_v2(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactOutMultiV2(asset, assetTo, lenderId);
        uint256 amountOut = 15.0e6;
        uint256 maximumIn = 15.5e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, maximumIn);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            amountOut, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;
        balanceFrom = balanceFrom - IERC20All(collateralAsset).balanceOf(user);

        //  swap 15 for approx 15
        assertApproxEqAbs(15116796, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_collateral_all_in_v2(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        {
            address borrowAsset = WMNT;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetTo = USDT;
        address collateralAssetTo = collateralTokens[assetTo][lenderId];

        bytes memory swapPath = getCollateralSwapExactInSingleV2(asset, assetTo, lenderId);
        uint256 minimumOut = 29.9399e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, 1e20);

        uint256 balanceFrom = IERC20All(collateralAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAssetTo).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            0, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAssetTo).balanceOf(user) - balance;

        // no collateral in left
        uint256 balanceFinal = IERC20All(collateralAsset).balanceOf(user);
        assertApproxEqAbs(balanceFinal, 0, 0);
        balanceFrom = balanceFrom - balanceFinal;

        //  swap 42 for approx 42
        assertApproxEqAbs(39122533, balanceFrom, 1);
        assertApproxEqAbs(38885941, balance, 1);
    }
}
