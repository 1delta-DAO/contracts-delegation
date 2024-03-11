// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashAggregator {
    /** MARGIN */

    function flashSwapExactIn(uint256 amountIn, uint256 amountOutMinimum, bytes calldata path) external payable returns (uint256 amountOut);

    function flashSwapExactOut(uint256 amountOut, uint256 amountInMaximum, bytes calldata path) external payable returns (uint256 amountIn);

    function flashSwapAllIn(uint256 amountOutMinimum, bytes calldata path) external payable returns (uint256 amountOut);

    function flashSwapAllOut(uint256 amountInMaximum, bytes calldata path) external payable returns (uint256 amountIn);

    /** SPOT */

    function swapExactOutSpot(uint256 amountOut, uint256 maximumAmountIn, bytes calldata path) external payable;

    function swapExactOutSpotSelf(uint256 amountOut, uint256 maximumAmountIn, bytes calldata path) external payable;

    function swapExactInSpot(uint256 amountIn, uint256 minimumAmountOut, bytes calldata path) external payable;

    function swapAllOutSpot(uint256 maximumAmountIn, uint8 lenderId, uint256 interestRateMode, bytes calldata path) external payable;

    function swapAllOutSpotSelf(uint256 maximumAmountIn, uint8 lenderId, uint256 interestRateMode, bytes calldata path) external payable;

    function swapAllInSpot(uint256 minimumAmountOut, bytes calldata path) external payable;
}
