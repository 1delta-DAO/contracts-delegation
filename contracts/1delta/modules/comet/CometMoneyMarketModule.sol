// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {
    MarginSwapParamsMultiExactOut,
    StandaloneExactInputUniswapParams,
    ExactInputCollateralMultiParams,
    ExactOutputCollateralMultiParams,
    ExactInputMoneyMarketMultiParams,
    ExactOutputMoneyMarketMultiParams,
    ExactInputMultiParams
    } from "../../dataTypes/CometInputTypes.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {TransferHelper} from "../../dex-tools/uniswap/libraries/TransferHelper.sol";
import {IUniswapV3ProviderModule} from "../../interfaces/IUniswapV3ProviderModule.sol";
import {INativeWrapper} from "../../interfaces/INativeWrapper.sol";
import {IComet} from "../../interfaces/IComet.sol";
import "../base/InternalSwapperComet.sol";

// solhint-disable max-line-length

/**
 * @title Money market module
 * @notice Allows users to chain a single money market transaction with a swap.
 * Direct lending pool interactions are unnecessary as the user can directly interact with the lending protocol
 * @author Achthar
 */
contract CometMoneyMarketModule is InternalSwapperComet {
    using Path for bytes;
    using SafeCast for uint256;

    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;

    constructor(address uniFactory) InternalSwapperComet(uniFactory) {}

    function wrapAndSupply(uint8 _cometId) external payable {
        address _nativeWrapper = us().weth;
        uint256 _amountToSupply = msg.value;
        INativeWrapper _weth = INativeWrapper(_nativeWrapper);
        _weth.deposit{value: _amountToSupply}();
        IComet(cos().comet[_cometId]).supplyTo(msg.sender, _nativeWrapper, _amountToSupply);
    }

    // exactly the same as wrapAndSupply
    function wrapAndRepay(uint8 _cometId) external payable {
        address _nativeWrapper = us().weth;
        uint256 _amountToSupply = msg.value;
        INativeWrapper _weth = INativeWrapper(_nativeWrapper);
        _weth.deposit{value: _amountToSupply}();
        IComet(cos().comet[_cometId]).supplyTo(msg.sender, _nativeWrapper, _amountToSupply);
    }

    function withdrawAndUnwrap(
        uint256 _amountToWithdraw,
        address payable _recipient,
        uint8 cometId
    ) external {
        address _nativeWrapper = us().weth;
        uint256 withdrawn = _amountToWithdraw;
        IComet(cos().comet[cometId]).withdrawFrom(msg.sender, address(this), _nativeWrapper, withdrawn);
        INativeWrapper _weth = INativeWrapper(_nativeWrapper);
        _weth.withdraw(withdrawn);
        _recipient.transfer(withdrawn);
    }

    function swapAndSupplyExactIn(ExactInputCollateralMultiParams memory params) external {
        uint256 amountIn = params.amountIn;
        TransferHelper.safeTransferFrom(params.path.getFirstToken(), msg.sender, address(this), amountIn);
        // swap to self
        uint256 amountToSupply = exactInputToSelf(amountIn, params.path);
        require(amountToSupply >= params.amountOutMinimum, "Received too little");
        // deposit received amount to aave on behalf of user
        IComet(cos().comet[params.cometId]).supplyTo(msg.sender, params.path.getLastToken(), amountToSupply);
    }

    function swapETHAndSupplyExactIn(ExactInputCollateralMultiParams calldata params) external payable {
        INativeWrapper _weth = INativeWrapper(us().weth);
        uint256 amountIn = params.amountIn;
        // wrap eth
        _weth.deposit{value: amountIn}();
        // swap to self
        uint256 amountToSupply = exactInputToSelf(amountIn, params.path);
        require(amountToSupply >= params.amountOutMinimum, "Received too little");
        // deposit received amount to the lending protocol on behalf of user
        IComet(cos().comet[params.cometId]).supplyTo(msg.sender, params.path.getLastToken(), amountToSupply);
    }

    function swapAndSupplyExactOut(MarginSwapParamsMultiExactOut calldata params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint256 amountOut = params.amountOut;
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 12,
            cometId: params.cometId,
            user: msg.sender,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Paid too much");

        // deposit received amount to aave on behalf of user
        IComet(cos().comet[params.cometId]).supplyTo(msg.sender, tokenOut, amountOut);
    }

    function swapETHAndSupplyExactOut(ExactOutputCollateralMultiParams calldata params) external payable returns (uint256 amountIn) {
        INativeWrapper _weth = INativeWrapper(us().weth);
        uint256 amountReceived = params.amountInMaximum;
        uint256 amountOut = params.amountOut;
        _weth.deposit{value: amountReceived}();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 12,
            cometId: 0,
            user: address(this),
            exactIn: false
        });

        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );
        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Paid too much");
        // deposit received amount to the lending protocol on behalf of user
        IComet(cos().comet[params.cometId]).supplyTo(msg.sender, params.path.getFirstToken(), params.amountOut);
        // refund dust - reverts if lippage too high
        amountReceived -= amountIn;
        _weth.withdraw(amountReceived);
        payable(msg.sender).transfer(amountReceived);
    }

    function withdrawAndSwapExactIn(ExactInputMoneyMarketMultiParams memory params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        uint256 amountIn = params.amountIn;
        // withraw and send funds to this address for swaps
        IComet(cos().comet[params.cometId]).withdrawFrom(msg.sender, address(this), tokenIn, amountIn);
        // then swap
        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        IERC20(params.path.getLastToken()).transfer(params.recipient, amountOut);
    }

    function withdrawAndSwapExactInToETH(ExactInputMoneyMarketMultiParams calldata params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        uint256 amountIn = params.amountIn;
        // withraw and send funds to this address for swaps
        IComet(cos().comet[params.cometId]).withdrawFrom(msg.sender, address(this), tokenIn, amountIn);
        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        INativeWrapper(us().weth).withdraw(amountOut);
        payable(params.recipient).transfer(amountOut);
    }

    function withdrawAndSwapExactOut(ExactOutputMoneyMarketMultiParams calldata params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 13,
            cometId: params.cometId,
            user: msg.sender,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            params.recipient,
            zeroForOne,
            -params.amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to withdraw too much");
    }

    function withdrawAndSwapExactOutToETH(MarginSwapParamsMultiExactOut calldata params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint256 amountOut = params.amountOut;
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 13,
            cometId: params.cometId,
            user: msg.sender,
            exactIn: false
        });
        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to withdraw too much");

        INativeWrapper(tokenOut).withdraw(amountOut);
        payable(msg.sender).transfer(amountOut);
    }

    function borrowAndSwapExactIn(ExactInputMoneyMarketMultiParams memory params) external returns (uint256 amountOut) {
        uint256 amountIn = params.amountIn;
        // borrow and send funds to this address for swaps
        IComet(cos().comet[params.cometId]).withdrawFrom(msg.sender, address(this), params.path.getFirstToken(), params.amountIn);
        // swap exact in with common router
        amountOut = exactInputToSelf(amountIn, params.path);
        IERC20(params.path.getLastToken()).transfer(params.recipient, amountOut);
        require(amountOut >= params.amountOutMinimum, "Received too little");
    }

    function borrowAndSwapExactInToETH(ExactInputMoneyMarketMultiParams calldata params) external returns (uint256 amountOut) {
        uint256 amountIn = params.amountIn;
        // borrow and send funds to this address for swaps
        IComet(cos().comet[params.cometId]).withdrawFrom(msg.sender, address(this), params.path.getFirstToken(), amountIn);
        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        INativeWrapper(us().weth).withdraw(amountOut);
        payable(params.recipient).transfer(amountOut);
    }

    function borrowAndSwapExactOut(MarginSwapParamsMultiExactOut memory params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 13,
            cometId: params.cometId,
            user: msg.sender,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            msg.sender,
            zeroForOne,
            -params.amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to borrow too much");
    }

    function borrowAndSwapExactOutToETH(MarginSwapParamsMultiExactOut calldata params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint256 amountOut = params.amountOut;
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 13,
            cometId: params.cometId,
            user: msg.sender,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;
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

        INativeWrapper(us().weth).withdraw(amountOut);
        payable(msg.sender).transfer(amountOut);
    }

    function swapAndRepayExactIn(ExactInputCollateralMultiParams calldata params) external returns (uint256 amountOut) {
        uint256 amountIn = params.amountIn;
        IERC20(params.path.getFirstToken()).transferFrom(msg.sender, address(this), amountIn);
        // swap to self
        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        // deposit received amount to aave on behalf of user
        IComet(cos().comet[params.cometId]).supplyTo(msg.sender, params.path.getLastToken(), amountOut);
    }

    function swapETHAndRepayExactIn(ExactInputMultiParams calldata params) external payable returns (uint256 amountOut) {
        INativeWrapper _weth = INativeWrapper(us().weth);
        uint256 amountIn = params.amountIn;
        // wrap eth
        _weth.deposit{value: amountIn}();
        // swap to self
        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        // deposit received amount to the lending protocol on behalf of user
        IComet(cos().comet[params.cometId]).supplyTo(msg.sender, params.path.getLastToken(), amountOut);
    }

    function swapAndRepayExactOut(MarginSwapParamsMultiExactOut memory params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint256 amountOut = params.amountOut;
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 12,
            cometId: params.cometId,
            user: msg.sender,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;
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

        // deposit received amount to aave on behalf of user
        IComet(cos().comet[params.cometId]).supplyTo(msg.sender, tokenOut, amountOut);
    }

    function swapETHAndRepayExactOut(ExactOutputCollateralMultiParams calldata params) external payable returns (uint256 amountIn) {
        INativeWrapper _weth = INativeWrapper(us().weth);
        uint256 amountReceived = params.amountInMaximum;
        _weth.deposit{value: amountReceived}();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 12,
            cometId: 0,
            user: address(this),
            exactIn: false
        });

        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        bool zeroForOne = tokenIn < tokenOut;
        uint256 amountOut = params.amountOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );
        amountIn = cs().amount;
        cs().amount = DEFAULT_AMOUNT_CACHED;
        // deposit received amount to the lending protocol on behalf of user
        IComet(cos().comet[params.cometId]).supplyTo(msg.sender, params.path.getFirstToken(), params.amountOut);
        // refund dust
        uint256 dust = amountReceived - amountIn;
        _weth.withdraw(dust);
        payable(msg.sender).transfer(dust);
    }
}
