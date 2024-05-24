// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashAggregator {
    /** MARGIN */

    function flashSwapExactIn(uint256 amountIn, uint256 amountOutMinimum, bytes calldata path) external payable;

    function flashSwapExactOut(uint256 amountOut, uint256 amountInMaximum, bytes calldata path) external payable;

    function flashSwapAllIn(uint256 amountOutMinimum, bytes calldata path) external payable;

    function flashSwapAllOut(uint256 amountInMaximum, bytes calldata path) external payable;

    /** SPOT */

    function flashSwapExactInSimple(uint256 amountIn, uint256 amountOutMinimum, bytes calldata path) external payable;

    function swapExactOutSpot(uint256 amountOut, uint256 maximumAmountIn, address receiver, bytes calldata path) external payable;

    function swapExactOutSpotSelf(uint256 amountOut, uint256 maximumAmountIn, bytes calldata path) external payable;

    function swapExactInSpot(uint256 amountIn, uint256 minimumAmountOut, address receiver, bytes calldata path) external payable;

    function swapExactInSpotSelf(uint256 amountIn, uint256 minimumAmountOut, bytes calldata path) external payable;

    function swapAllOutSpot(uint256 maximumAmountIn, uint8 lenderId, uint256 interestRateMode, bytes calldata path) external payable;

    function swapAllOutSpotSelf(uint256 maximumAmountIn, uint8 lenderId, uint256 interestRateMode, bytes calldata path) external payable;

    function swapAllInSpot(uint256 minimumAmountOut, bytes calldata path) external payable;

    /** CALLBACKS */

    // fusionx
    function fusionXV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;

    // agni
    function agniSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external;

    // swapsicle
    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external;

    // butter
    function butterSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external;

    // cleo
    function ramsesV2SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external;

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external;

    // The uniswapV2 style callback for fusionX
    function FusionXCall(address, uint256 amount0, uint256 amount1, bytes calldata data) external;

    // The uniswapV2 style callback for Merchant Moe
    function moeCall(address, uint256 amount0, uint256 amount1, bytes calldata data) external;

    // The uniswapV2 style callback for Velocimeter, Cleopatra V and Stratum
    function hook(address, uint256 amount0, uint256 amount1, bytes calldata data) external;

    // iZi callbacks

    // zeroForOne = true
    function swapY2XCallback(uint256 x, uint256 y, bytes calldata path) external;

    // zeroForOne = false
    function swapX2YCallback(uint256 x, uint256 y, bytes calldata path) external;
}
