// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import {DexConfigMantle} from "./DexConfig.f.sol";

contract MarginCloseTest is DeltaSetup, DexConfigMantle {
    address testUser = 0xcccccda06B44bcc94618620297Dc252EcfB56d85;

    uint256 DEFAULT_IR_MODE = 2; // variable

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 60500956, urlOrAlias: "https://rpc.ankr.com/mantle"});

        deployDelta();
        initializeDelta();
    }

    function test_margin_mantle_close_exact_in() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = 1;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactInSingle(asset, borrowAsset, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.0e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(14005000729747140590, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_in_multi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = 1;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactInMulti(asset, borrowAsset, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 9.0e18; // this one provides a bad swap rate
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(9189374971189364158, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_out() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = 1;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactOutSingle(asset, borrowAsset, lenderId);
        uint256 amountOut = 15.0e18;
        uint256 amountInMaximum = 17.0e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, amountInMaximum, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(16067704, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_out_multi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = 1;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactOutMulti(asset, borrowAsset, lenderId);
        uint256 amountOut = 1.0e18;
        uint256 amountInMaximum = 17.0e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, amountInMaximum, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(1138292, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    /** HELPER FUNCTIONS */

    function openSimple(address user, address asset, address borrowAsset, uint256 depositAmount, uint256 borrowAmount, uint8 lenderId) private {
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, depositAmount);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, depositAmount);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        bytes memory swapPath = getOpenExactInSingle(borrowAsset, asset, lenderId);
        uint256 minimumOut = 30.0e6;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, borrowAmount, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, depositAmount);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, borrowAmount);

        vm.prank(user);
        brokerProxy.multicall(calls);
    }

    function getOpenExactInSingle(address tokenIn, address tokenOut, uint8 lenderId) private view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(lenderId, tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getCloseExactOutSingle(address tokenIn, address tokenOut, uint8 lenderId) private view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(lenderId, tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getCloseExactInSingle(address tokenIn, address tokenOut, uint8 lenderId) private view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(lenderId, tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getCloseExactInMulti(address tokenIn, address tokenOut, uint8 lenderId) private view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = IZUMI;
        bytes memory firstPart = abi.encodePacked(lenderId, tokenIn, fee, poolId, actionId, USDT);
        fee = DEX_FEE_STABLES;
        poolId = FUSION_X;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getCloseExactOutMulti(address tokenIn, address tokenOut, uint8 lenderId) private view returns (bytes memory data) {
        uint24 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = FUSION_X;
        bytes memory firstPart = abi.encodePacked(lenderId, tokenOut, fee, poolId, actionId, USDT);
        fee = DEX_FEE_LOW;
        poolId = IZUMI;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }
}
