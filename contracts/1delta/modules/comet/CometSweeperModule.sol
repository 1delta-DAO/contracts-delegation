// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {
    AllInputMultiParamsBase,
    AllOutputMultiParamsBase,
    ExactOutputMultiParams,
    AllInputMoneyMarketMultiParams
    } from "../../dataTypes/CometInputTypes.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {TransferHelper} from "../../dex-tools/uniswap/libraries/TransferHelper.sol";
import {IUniswapV3Pool} from "../../dex-tools/uniswap/core/IUniswapV3Pool.sol";
import {CallbackValidation} from "../../dex-tools/uniswap/libraries/CallbackValidation.sol";
import {INativeWrapper} from "../../interfaces/INativeWrapper.sol";
import {IERC20Balance} from "../../interfaces/IERC20Balance.sol";
import {IComet} from "../../interfaces/IComet.sol";
import "../base/InternalSwapperComet.sol";

// solhint-disable max-line-length

/**
 * @title Sweeper module
 * @notice Contract to handle sewwping transactions, i.e. transaction with the objective to prevent dust
 * This cannot always work in swap scenarios with withdrawals, however, for repaying debt, the methods are consistent.
 * @author Achthar
 */
contract CometSweeperModule is InternalSwapperComet {
    using Path for bytes;
    using SafeCast for uint256;

    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;

    constructor(address uniFactory) InternalSwapperComet(uniFactory) {}

    function withdrawAndSwapAllIn(AllInputMoneyMarketMultiParams memory params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        address comet = cos().comet[params.cometId];
        uint256 amountIn = IComet(comet).userCollateral(msg.sender, tokenIn).balance;

        // withraw and send funds to this address for swaps
        IComet(comet).withdrawFrom(msg.sender, address(this), tokenIn, amountIn);

        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        IERC20(params.path.getLastToken()).transfer(params.recipient, amountOut);
    }

    function withdrawAndSwapAllInToETH(AllInputMoneyMarketMultiParams calldata params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        address comet = cos().comet[params.cometId];
        uint256 amountIn = IComet(comet).userCollateral(msg.sender, tokenIn).balance;

        // withraw and send funds to this address for swaps
        IComet(cos().comet[params.cometId]).withdrawFrom(msg.sender, address(this), tokenIn, amountIn);

        // set amount in for Uniswap, right after withdrawing everything
        amountOut = exactInputToSelf(amountIn, params.path);
        INativeWrapper(us().weth).withdraw(amountOut);
        payable(params.recipient).transfer(amountOut);
        require(amountOut >= params.amountOutMinimum, "Received too little");
    }

    function withdrawBaseAndSwapAllIn(AllInputMoneyMarketMultiParams memory params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        address comet = cos().comet[params.cometId];
        uint256 amountIn = IComet(comet).balanceOf(msg.sender);

        // withraw and send funds to this address for swaps
        IComet(comet).withdrawFrom(msg.sender, address(this), tokenIn, amountIn);

        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        IERC20(params.path.getLastToken()).transfer(params.recipient, amountOut);
    }

    function withdrawBaseAndSwapAllInToETH(AllInputMoneyMarketMultiParams calldata params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        address comet = cos().comet[params.cometId];
        uint256 amountIn = IComet(comet).balanceOf(msg.sender);

        // withraw and send funds to this address for swaps
        IComet(cos().comet[params.cometId]).withdrawFrom(msg.sender, address(this), tokenIn, amountIn);

        // set amount in for Uniswap, right after withdrawing everything
        amountOut = exactInputToSelf(amountIn, params.path);
        INativeWrapper(us().weth).withdraw(amountOut);
        payable(params.recipient).transfer(amountOut);
        require(amountOut >= params.amountOutMinimum, "Received too little");
    }

    function swapAndRepayAllOut(AllOutputMultiParamsBase calldata params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 12,
            cometId: params.cometId,
            user: msg.sender,
            exactIn: true
        });
        // amount out is the full debt balance
        uint256 amountOut = IComet(cos().comet[params.cometId]).borrowBalanceOf(msg.sender);
        bool zeroForOne = tokenIn < tokenOut;
        (int256 amount0, int256 amount1) = _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -int256(amountOut),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );
        uint256 amountToRepay = zeroForOne ? uint256(-amount1) : uint256(-amount0);
        // it's technically possible to not receive the full output amount,
        // so if no price limit has been specified, require this possibility away
        require(amountToRepay == amountOut);

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to pay too much");

        // deposit received amount to aave on behalf of user
        IComet(cos().comet[params.cometId]).supplyTo(msg.sender, tokenOut, amountToRepay);
    }

    // amountOut will be ignored and replaced with the target maximum repay amount
    function swapETHAndRepayAllOut(AllOutputMultiParamsBase calldata params) external payable returns (uint256 amountIn) {
        INativeWrapper _weth = INativeWrapper(us().weth);
        address comet = cos().comet[params.cometId];
        uint256 amountReceived = params.amountInMaximum;
        _weth.deposit{value: amountReceived}();
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 12, cometId: 0, user: address(this), exactIn: false});
        // amount out is the full debt balance
        uint256 amountOut = IComet(comet).borrowBalanceOf(msg.sender);
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
        IComet(comet).supplyTo(msg.sender, params.path.getFirstToken(), amountOut);
        // refund dust
        amountReceived -= amountIn;
        _weth.withdraw(amountReceived);
        payable(msg.sender).transfer(amountReceived);
    }

    // margin trader functions

    // swaps the collateral from one token (tokenIn) to another (tokenOut) provided tokenOut amount
    function swapCollateralAllIn(AllInputMultiParamsBase calldata params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 4,
            user: msg.sender,
            cometId: params.cometId,
            exactIn: true
        });

        bool zeroForOne = tokenIn < tokenOut;
        // if the asset were the abse asset, it implicates that there is no borrow - no margin trade required in that case
        uint256 amountIn = IComet(cos().comet[params.cometId]).userCollateral(msg.sender, tokenIn).balance;
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

    // swaps all the base token collateral to another colalteral token 
    function swapBaseCollateralAllIn(AllInputMultiParamsBase calldata params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 4,
            user: msg.sender,
            cometId: params.cometId,
            exactIn: true
        });

        bool zeroForOne = tokenIn < tokenOut;
        // if the asset were the abse asset, it implicates that there is no borrow - no margin trade required in that case
        uint256 amountIn = IComet(cos().comet[params.cometId]).balanceOf(msg.sender);
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

    // decrease the margin position - use the collateral (tokenIn) to pay back a borrow (tokenOut)
    function trimMarginPositionAllIn(AllInputMultiParamsBase calldata params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 10,
            user: msg.sender,
            cometId: params.cometId,
            exactIn: true
        });

        bool zeroForOne = tokenIn < tokenOut;
        // can only be a non-baseAsset
        uint256 amountIn = IComet(cos().comet[params.cometId]).userCollateral(msg.sender, tokenIn).balance;
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
            cometId: params.cometId,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;

        uint256 amountOut = IComet(cos().comet[params.cometId]).borrowBalanceOf(msg.sender);
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
}
