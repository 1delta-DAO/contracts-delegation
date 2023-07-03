// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {
    MarginCallbackData, 
    ExactInputMultiParams, 
    ExactOutputMultiParams, 
    MarginSwapParamsMultiExactIn,
    MarginSwapParamsMultiExactOut,
    ExactInputCollateralMultiParams,
    ExactOutputCollateralMultiParams
    } from "../../dataTypes/CometInputTypes.sol";
import {IMarginTrader} from "../../interfaces/IMarginTrader.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {TokenTransfer} from "../../libraries/TokenTransfer.sol";
import "../base/InternalSwapperComet.sol";

// solhint-disable max-line-length

/**
 * @title MarginTrader contract
 * @notice Allows users to build large margin positions with one contract interaction
 * @author Achthar
 */
contract CometMarginTraderModule is InternalSwapperComet, TokenTransfer {
    using Path for bytes;
    using SafeCast for uint256;

    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;

    constructor(address uniFactory) InternalSwapperComet(uniFactory) {}

    function swapBorrowExactIn(ExactInputMultiParams memory params) external payable returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 2,
            cometId: params.cometId,
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
        require(params.amountOutMinimum <= amountOut, "Repaid too little");
    }

    // swaps the loan from one token (tokenIn) to another (tokenOut) provided tokenOut amount
    function swapBorrowExactOut(ExactOutputMultiParams memory params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 2,
            cometId: params.cometId,
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
        require(params.amountInMaximum >= amountIn, "Had to borrow too much");
    }

    // swaps the collateral from one token (tokenIn) to another (tokenOut) provided tokenOut amount
    function swapCollateralExactIn(ExactInputCollateralMultiParams memory params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 4,
            cometId: params.cometId,
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
        require(params.amountOutMinimum <= amountOut, "Deposited too little");
    }

    // swaps the collateral from one token (tokenIn) to another (tokenOut) provided tokenOut amount
    function swapCollateralExactOut(ExactOutputCollateralMultiParams memory params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 4,
            cometId: params.cometId,
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
        require(params.amountInMaximum >= amountIn, "Had to withdraw too much");
    }

    // increase the margin position - borrow (tokenIn) and sell it against collateral (tokenOut)
    // the user provides the debt amount as input
    function openMarginPositionExactIn(MarginSwapParamsMultiExactIn memory params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 8,
            cometId: params.cometId,
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
        require(params.amountOutMinimum <= amountOut, "Deposited too little");
    }

    // increase the margin position - borrow (tokenIn) and sell it against collateral (tokenOut)
    // the user provides the collateral amount as input
    function openMarginPositionExactOut(MarginSwapParamsMultiExactOut memory params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 8,
            cometId: params.cometId,
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
        require(params.amountInMaximum >= amountIn, "Had to borrow too much");
    }

    // decrease the margin position - use the collateral (tokenIn) to pay back a borrow (tokenOut)
    function trimMarginPositionExactIn(MarginSwapParamsMultiExactIn memory params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 10,
            cometId: params.cometId,
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
        require(params.amountOutMinimum <= amountOut, "Repaid too little");
    }

    function trimMarginPositionExactOut(MarginSwapParamsMultiExactOut memory params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 10,
            cometId: params.cometId,
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
        require(params.amountInMaximum >= amountIn, "Had to withdraw too much");
    }
}
