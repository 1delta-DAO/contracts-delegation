// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import {
    ExactInputMultiParams, 
    ExactOutputMultiParams,
    MarginSwapParamsMultiExactIn,
    MarginSwapParamsMultiExactOut,
    ExactInputCollateralMultiParams,
    CollateralParamsMultiExactOut
    } from "../../dataTypes/InputTypes.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import "../base/InternalSwapper.sol";

// solhint-disable max-line-length

/**
 * @title MarginTrader contract
 * @notice Allows users to build large margin positions with one contract interaction
 * @author Achthar
 */
contract AAVEMarginTraderModule is InternalSwapper {
    using Path for bytes;
    using SafeCast for uint256;

    error Slippage();

    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;

    constructor(address uniFactory) InternalSwapper(uniFactory) {}

    function swapBorrowExactIn(ExactInputMultiParams memory params) external payable returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 2,
            interestRateMode: params.interestRateMode,
            user: msg.sender,
            exactIn: true
        });

        bool zeroForOne = tokenIn < tokenOut;

        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            params.amountIn.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountOut = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        if(params.amountOutMinimum > amountOut) revert Slippage();
    }

    // swaps the loan from one token (tokenIn) to another (tokenOut) provided tokenOut amount
    function swapBorrowExactOut(ExactOutputMultiParams memory params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 2,
            interestRateMode: params.interestRateMode,
            user: msg.sender,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;

        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -params.amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        if(params.amountInMaximum < amountIn) revert Slippage();
    }

    // swaps the collateral from one token (tokenIn) to another (tokenOut) provided tokenOut amount
    function swapCollateralExactIn(ExactInputCollateralMultiParams memory params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();
        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 4, interestRateMode: 0, user: msg.sender, exactIn: true});

        bool zeroForOne = tokenIn < tokenOut;

        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            params.amountIn.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountOut = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        if(params.amountOutMinimum > amountOut) revert Slippage();
    }

    // swaps the collateral from one token (tokenIn) to another (tokenOut) provided tokenOut amount
    function swapCollateralExactOut(CollateralParamsMultiExactOut memory params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 4, interestRateMode: 0, user: msg.sender, exactIn: false});

        bool zeroForOne = tokenIn < tokenOut;

        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -params.amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        if(params.amountInMaximum < amountIn) revert Slippage();
    }

    // increase the margin position - borrow (tokenIn) and sell it against collateral (tokenOut)
    // the user provides the debt amount as input
    function openMarginPositionExactIn(MarginSwapParamsMultiExactIn memory params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 8,
            interestRateMode: params.interestRateMode,
            user: msg.sender,
            exactIn: true
        });

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            params.amountIn.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountOut = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        if(params.amountOutMinimum > amountOut) revert Slippage();
    }

    // increase the margin position - borrow (tokenIn) and sell it against collateral (tokenOut)
    // the user provides the collateral amount as input
    function openMarginPositionExactOut(MarginSwapParamsMultiExactOut memory params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 8,
            interestRateMode: params.interestRateMode,
            user: msg.sender,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -params.amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        if(params.amountInMaximum < amountIn) revert Slippage();
    }

    // decrease the margin position - use the collateral (tokenIn) to pay back a borrow (tokenOut)
    function trimMarginPositionExactIn(MarginSwapParamsMultiExactIn memory params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 10,
            interestRateMode: params.interestRateMode,
            user: msg.sender,
            exactIn: true
        });

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            params.amountIn.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountOut = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        if(params.amountOutMinimum > amountOut) revert Slippage();
    }

    function trimMarginPositionExactOut(MarginSwapParamsMultiExactOut memory params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 10,
            interestRateMode: params.interestRateMode,
            user: msg.sender,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -params.amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );
        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        if(params.amountInMaximum < amountIn) revert Slippage();
    }
}
