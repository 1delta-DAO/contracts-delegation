// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {
    AllInputMultiParamsBase,
    AllOutputMultiParamsBase,
    AllInputCollateralMultiParamsBase,
    ExactOutputMultiParams,
    AllInputCollateralMultiParamsBaseWithRecipient
    } from "../../dataTypes/InputTypes.sol";
import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {CallbackValidation} from "../../dex-tools/uniswap/libraries/CallbackValidation.sol";
import {INativeWrapper} from "../../interfaces/INativeWrapper.sol";
import {IERC20Balance} from "../../interfaces/IERC20Balance.sol";
import "../base/InternalSwapper.sol";

// solhint-disable max-line-length

/**
 * @title Sweeper module
 * @notice Contract to handle sewwping transactions, i.e. transaction with the objective to prevent dust
 * This cannot always work in swap scenarios with withdrawals, however, for repaying debt, the methods are consistent.
 * @author Achthar
 */
contract AAVESweeperModule is InternalSwapper, TokenTransfer {
    using Path for bytes;
    using SafeCast for uint256;

    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;

    IPool private immutable _aavePool;

    constructor(address uniFactory, address aavePool) InternalSwapper(uniFactory) {
        _aavePool = IPool(aavePool);
    }

    function getDebtBalance(address token, uint256 interestRateMode) private view returns (uint256) {
        if (interestRateMode == 2) return IERC20Balance(aas().vTokens[token]).balanceOf(msg.sender);
        else return IERC20Balance(aas().sTokens[token]).balanceOf(msg.sender);
    }

    function getCollateralBalance(address token) private view returns (uint256) {
        return IERC20Balance(aas().aTokens[token]).balanceOf(msg.sender);
    }

    // money market function

    function withdrawAndSwapAllIn(AllInputCollateralMultiParamsBaseWithRecipient calldata params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        address aToken = aas().aTokens[tokenIn];
        uint256 amountIn = IERC20Balance(aToken).balanceOf(msg.sender);
        // we have to transfer aTokens from the user to this address - these are used to access liquidity
        _transferERC20TokensFrom(aToken, msg.sender, address(this), amountIn);
        // we withdraw everything
        amountIn = withdrawAll(tokenIn);

        // swap to self
        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        _transferERC20Tokens(params.path.getLastToken(), params.recipient, amountOut);
    }

    function withdrawAndSwapAllInToETH(AllInputCollateralMultiParamsBaseWithRecipient calldata params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        address aToken = aas().aTokens[tokenIn];
        uint256 amountIn = IERC20Balance(aToken).balanceOf(msg.sender);
        // we have to transfer aTokens from the user to this address - these are used to access liquidity
        _transferERC20TokensFrom(aToken, msg.sender, address(this), amountIn);
        // we withdraw everything
        amountIn = withdrawAll(tokenIn);
        // swap to self
        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");

        INativeWrapper(us().weth).withdraw(amountOut);
        payable(params.recipient).transfer(amountOut);
        require(amountOut >= params.amountOutMinimum, "Received too little");
    }

    function swapAndRepayAllOut(AllOutputMultiParamsBase calldata params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 12,
            interestRateMode: params.interestRateMode,
            user: msg.sender,
            exactIn: false
        });
        // amount out is the full debt balance
        uint256 amountOut = getDebtBalance(tokenOut, params.interestRateMode);
        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -int256(amountOut),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to pay too much");

        // deposit received amount to aave on behalf of user
        _aavePool.repay(tokenOut, amountOut, params.interestRateMode, msg.sender);
    }

    // amountOut will be ignored and replaced with the target maximum repay amount
    function swapETHAndRepayAllOut(AllOutputMultiParamsBase calldata params) external payable returns (uint256 amountIn) {
        INativeWrapper _weth = INativeWrapper(us().weth);
        uint256 amountReceived = msg.value;
        _weth.deposit{value: amountReceived}();
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint8 interestMode = params.interestRateMode;
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 12,
            interestRateMode: 0,
            user: address(this),
            exactIn: false
        });
        // amount out is the full debt balance
        uint256 amountOut = getDebtBalance(tokenOut, interestMode);
        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -int256(amountOut),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to pay too much");

        // deposit received amount to the lending protocol on behalf of user
        _aavePool.repay(tokenOut, amountOut, interestMode, msg.sender);
        // refund dust
        amountReceived -=  amountIn;
        _weth.withdraw(amountReceived);
        payable(msg.sender).transfer(amountReceived);
    }

    // margin trader functions

    // swaps the loan from one token (tokenIn) to another (tokenOut) provided tokenOut amount
    function swapBorrowAllOut(AllOutputMultiParamsBase calldata params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 2,
            user: msg.sender,
            interestRateMode: params.interestRateMode,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;

        uint256 amountOut = getDebtBalance(tokenOut, params.interestRateMode % 10);
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to borrow too much");
    }

    // swaps the collateral from one token (tokenIn) to another (tokenOut) provided tokenOut amount
    function swapCollateralAllIn(AllInputCollateralMultiParamsBase calldata params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();
        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 4, user: msg.sender, interestRateMode: 0, exactIn: true});

        bool zeroForOne = tokenIn < tokenOut;

        uint256 amountIn = getCollateralBalance(params.path.getFirstToken());
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            amountIn.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountOut = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountOutMinimum <= amountOut, "Deposited too little");
    }

    // ================= Trimming Positions ==========================

    // decrease the margin position - use the collateral (tokenIn) to pay back a borrow (tokenOut)
    function trimMarginPositionAllIn(AllInputMultiParamsBase calldata params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 10,
            user: msg.sender,
            interestRateMode: params.interestRateMode,
            exactIn: true
        });

        bool zeroForOne = tokenIn < tokenOut;

        uint256 amountIn = getCollateralBalance(tokenIn);
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            amountIn.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountOut = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountOutMinimum <= amountOut, "Repaid too little");
    }

    function trimMarginPositionAllOut(AllOutputMultiParamsBase calldata params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 10,
            user: msg.sender,
            interestRateMode: params.interestRateMode,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;

        uint256 amountOut = getDebtBalance(tokenOut, params.interestRateMode);
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to pay too much");
    }

    function withdrawAll(address asset) private returns (uint256 withdrawn) {
        withdrawn = _aavePool.withdraw(asset, type(uint256).max, address(this));
    }
}
