// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import {MarginSwapParamsMultiExactOut, CollateralParamsMultiExactIn, CollateralParamsMultiExactOut, ExactOutputCollateralMultiParams, CollateralWithdrawParamsMultiExactIn, CollateralParamsMultiNativeExactIn, MoneyMarketParamsMultiExactIn, ExactInputMultiParams} from "../../dataTypes/InputTypes.sol";
import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {IUniswapV3Pool} from "../../dex-tools/uniswap/core/IUniswapV3Pool.sol";
import {INativeWrapper} from "../../interfaces/INativeWrapper.sol";
import "../base/InternalSwapper.sol";
import {BaseSwapper} from "../base/BaseSwapper.sol";
import {IERC20Balance} from "../../interfaces/IERC20Balance.sol";

// solhint-disable max-line-length

/**
 * @title Money market module
 * @notice Allows users to chain a single money market transaction with a swap.
 * Direct lending pool interactions are unnecessary as the user can directly interact with the lending protocol
 * @author Achthar
 */
contract AaveMoneyMarket is InternalSwapper, TokenTransfer {
    using Path for bytes;
    using SafeCast for uint256;

    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;

    IPool private immutable _aavePool;

    address private immutable networkTokenId = address(0);
    address private immutable wrappedNative;

    constructor(
        address uniFactory,
        address aavePool,
        address weth
    ) InternalSwapper(uniFactory) {
        _aavePool = IPool(aavePool);
        wrappedNative = weth;
    }

    function wrapAndDeposit() external payable returns (uint256 supplied) {
        address _nativeWrapper = us().weth;
        supplied = msg.value;
        INativeWrapper _weth = INativeWrapper(_nativeWrapper);
        _weth.deposit{value: supplied}();
        _aavePool.supply(_nativeWrapper, supplied, msg.sender, 0);
    }

    struct DepositParameters {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        address recipient;
        address target;
        bytes data;
    }

    function callAndDeposit(DepositParameters calldata params) external payable {
        address tokenIn = params.tokenIn;
        // if tokenIn is the network currency, wrap asset
        if (tokenIn == networkTokenId) {
            tokenIn = wrappedNative;
            require(msg.value > 0, "NO_ETHER_SENT");
            INativeWrapper(tokenIn).deposit{value: msg.value}();
        } else _transferERC20TokensFrom(tokenIn, msg.sender, address(this), params.amountIn);

        address tokenOut = params.tokenOut;
        // exectue call
        {
            address target = params.target;
            require(gs().isValidTarget[target], "TARGET");
            (bool success, ) = target.call(params.data);
            require(success, "CALL_FAILED");
        }
        uint256 received = IERC20Balance(tokenOut).balanceOf(address(this));
        // note that we wrapped the entire amount, we will therefore refund wrapped native in case of ETH in
        uint256 remaining = IERC20Balance(tokenIn).balanceOf(address(this));
        if (remaining > 0) _transferERC20Tokens(tokenIn, msg.sender, remaining);
        _aavePool.supply(tokenOut, received, params.recipient, 0);
    }

    struct RepayParameters {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint8 interestRateMode;
        address recipient;
        address target;
        bytes data;
    }

    function callAndRepay(RepayParameters calldata params) external payable {
        // fetch tokenIn and transfer funds
        address tokenIn = params.tokenIn;
        // if tokenIn is the network currency, wrap asset
        if (tokenIn == networkTokenId) {
            tokenIn = wrappedNative;
            require(msg.value > 0, "NO_ETHER_SENT");
            INativeWrapper(tokenIn).deposit{value: msg.value}();
        } else _transferERC20TokensFrom(tokenIn, msg.sender, address(this), params.amountIn);

        address tokenOut = params.tokenOut;

        // exectue call
        {
            address target = params.target;
            require(gs().isValidTarget[target], "TARGET");
            (bool success, ) = target.call(params.data);
            require(success, "CALL_FAILED");
        }

        // fetch received amount
        uint256 received = IERC20Balance(tokenOut).balanceOf(address(this));
        // note that we wrapped the entire amount, we will therefore refund wrapped native in case of ETH in
        uint256 remaining = IERC20Balance(tokenIn).balanceOf(address(this));
        if (remaining > 0) _transferERC20Tokens(tokenIn, msg.sender, remaining);
        // reassign variable to prevent new slot
        remaining = params.interestRateMode;
        uint256 debtBalance;
        if (remaining == 2) debtBalance = IERC20Balance(aas().vTokens[tokenOut]).balanceOf(msg.sender);
        else debtBalance = IERC20Balance(aas().sTokens[tokenOut]).balanceOf(msg.sender);

        // repay obtained amount if less than debt
        if (debtBalance >= received) _aavePool.repay(tokenOut, received, remaining, params.recipient);
        else {
            address recipient = params.recipient;
            // otherwise, repay entire debt balance and refund dust
            _aavePool.repay(tokenOut, received, remaining, recipient);
            _transferERC20Tokens(tokenOut, recipient, received - debtBalance);
        }
    }

    struct BorrowParameters {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint8 interestRateMode;
        address recipient;
        address target;
        bytes data;
    }

    function borrowAndCall(BorrowParameters calldata params) external payable {
        // fetch tokenIn and transfer funds
        address tokenIn = params.tokenIn;
        _aavePool.borrow(tokenIn, params.amountIn, params.interestRateMode, 0, msg.sender); //(tokenOut, received, remaining, recipient);

        // exectue call
        (bool success, ) = params.target.call(params.data);
        require(success, "CALL_FAILED");

        address tokenOut = params.tokenOut;
        // fetch received amount
        uint256 received = IERC20Balance(tokenOut).balanceOf(address(this));
        // note that we send the funds to the user instead of repaying them
        uint256 remaining = IERC20Balance(tokenIn).balanceOf(address(this));
        if (remaining > 0) _transferERC20Tokens(tokenIn, msg.sender, remaining);
        // reassign variable to prevent new slot
        remaining = params.interestRateMode;
        uint256 debtBalance;
        if (remaining == 2) debtBalance = IERC20Balance(aas().vTokens[tokenOut]).balanceOf(msg.sender);
        else debtBalance = IERC20Balance(aas().sTokens[tokenOut]).balanceOf(msg.sender);

        // repay obtained amount if less than debt
        if (debtBalance >= received) _aavePool.repay(tokenOut, received, remaining, params.recipient);
        else {
            address recipient = params.recipient;
            // otherwise, repay entire debt balance and refund dust
            _aavePool.repay(tokenOut, received, remaining, recipient);
            _transferERC20Tokens(tokenOut, recipient, received - debtBalance);
        }

        // if tokenIn is the network currency, wrap asset
        if (tokenIn == networkTokenId) {
            tokenIn = wrappedNative;
            require(msg.value > 0, "NO_ETHER_SENT");
            INativeWrapper(tokenIn).deposit{value: msg.value}();
        } else _transferERC20TokensFrom(tokenIn, msg.sender, address(this), params.amountIn);
    }

    function wrapAndRepayAll(uint256 interestRateMode) external payable returns (uint256 repaid) {
        address _nativeWrapper = us().weth;
        INativeWrapper _weth = INativeWrapper(_nativeWrapper);
        // fetch borrow balance
        if (interestRateMode == 2) repaid = IERC20(aas().vTokens[_nativeWrapper]).balanceOf(msg.sender);
        else repaid = IERC20(aas().sTokens[_nativeWrapper]).balanceOf(msg.sender);
        // deposit projected borrow balance
        _weth.deposit{value: repaid}();
        // returns the actual amount repaid, should match the target value
        repaid = _aavePool.repay(_nativeWrapper, repaid, interestRateMode, msg.sender);
        // refund excess eth
        payable(msg.sender).transfer(msg.value - repaid);
    }

    function wrapAndRepay(uint256 interestRateMode) external payable returns (uint256 repaid) {
        address _nativeWrapper = us().weth;
        repaid = msg.value;
        INativeWrapper _weth = INativeWrapper(_nativeWrapper);
        _weth.deposit{value: repaid}();
        repaid = _aavePool.repay(_nativeWrapper, repaid, interestRateMode, msg.sender);
    }

    function withdrawAndUnwrap(uint256 amountToWithdraw, address payable recipient) external returns (uint256 withdrawn) {
        address _nativeWrapper = us().weth;
        withdrawn = amountToWithdraw;
        _transferERC20TokensFrom(aas().aTokens[_nativeWrapper], msg.sender, address(this), withdrawn);
        withdrawn = _aavePool.withdraw(_nativeWrapper, withdrawn, address(this));
        INativeWrapper _weth = INativeWrapper(_nativeWrapper);
        _weth.withdraw(withdrawn);
        // transfer eth to recipient
        recipient.transfer(withdrawn);
    }

    function withdrawAllAndUnwrap(address payable recipient) external returns (uint256 withdrawn) {
        address _nativeWrapper = us().weth;
        address _aToken = aas().aTokens[_nativeWrapper];
        withdrawn = IERC20(_aToken).balanceOf(msg.sender);
        _transferERC20TokensFrom(_aToken, msg.sender, address(this), withdrawn);
        withdrawn = _aavePool.withdraw(_nativeWrapper, withdrawn, address(this));
        INativeWrapper _weth = INativeWrapper(_nativeWrapper);
        _weth.withdraw(withdrawn);
        // transfer eth to recipient
        recipient.transfer(withdrawn);
    }

    function borrowAndUnwrap(
        uint256 amountToBorrow,
        address payable recipient,
        uint8 interestRateMode
    ) external {
        address _nativeWrapper = us().weth;
        uint256 borrowAmount = amountToBorrow;
        _aavePool.borrow(_nativeWrapper, borrowAmount, interestRateMode, 0, msg.sender);
        INativeWrapper _weth = INativeWrapper(_nativeWrapper);
        _weth.withdraw(borrowAmount);
        // transfer eth to recipient
        recipient.transfer(borrowAmount);
    }

    function swapAndSupplyExactIn(CollateralParamsMultiExactIn memory params) external {
        uint256 amountIn = params.amountIn;
        _transferERC20TokensFrom(params.path.getFirstToken(), msg.sender, address(this), amountIn);
        // swap to self
        uint256 amountToSupply = exactInputToSelf(amountIn, params.path);
        require(amountToSupply >= params.amountOutMinimum, "Received too little");
        // deposit received amount to aave on behalf of user
        _aavePool.supply(params.path.getLastToken(), amountToSupply, msg.sender, 0);
    }

    function swapETHAndSupplyExactIn(CollateralParamsMultiExactIn calldata params) external payable {
        INativeWrapper _weth = INativeWrapper(us().weth);
        uint256 amountIn = params.amountIn;
        // wrap eth
        _weth.deposit{value: amountIn}();
        // swap to self
        uint256 amountToSupply = exactInputToSelf(amountIn, params.path);
        require(amountToSupply >= params.amountOutMinimum, "Received too little");
        // deposit received amount to the lending protocol on behalf of user
        _aavePool.supply(params.path.getLastToken(), amountToSupply, msg.sender, 0);
    }

    function swapAndSupplyExactOut(ExactOutputCollateralMultiParams calldata params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint256 amountOut = params.amountOut;
        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 12, interestRateMode: 0, exactIn: false});

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Paid too much");

        // deposit received amount to aave on behalf of user
        _aavePool.supply(tokenOut, amountOut, msg.sender, 0);
    }

    // for this function it has to be made sure that the input amount matches the ETH amount sent
    // to enable this function in multicalls, one can still just send the total ETH amount in advance,
    // and then multicall this function
    function swapETHAndSupplyExactOut(CollateralParamsMultiExactOut calldata params) external payable returns (uint256 amountIn) {
        INativeWrapper _weth = INativeWrapper(us().weth);
        uint256 amountReceived = params.amountInMaximum;
        uint256 amountOut = params.amountOut;
        _weth.deposit{value: amountReceived}();

        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 12, interestRateMode: 0, exactIn: false});

        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );
        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;

        // deposit received amount to the lending protocol on behalf of user
        _aavePool.supply(tokenOut, amountOut, msg.sender, 0);
        // refund dust - reverts if lippage too high
        amountReceived -= amountIn;
        _weth.withdraw(amountReceived);
        payable(msg.sender).transfer(amountReceived);
    }

    function withdrawAndSwapExactIn(CollateralWithdrawParamsMultiExactIn memory params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        uint256 actuallyWithdrawn = params.amountIn;
        // we have to transfer aTokens from the user to this address - these are used to access liquidity
        _transferERC20TokensFrom(aas().aTokens[tokenIn], msg.sender, address(this), actuallyWithdrawn);
        // withraw and send funds to this address for swaps
        actuallyWithdrawn = _aavePool.withdraw(tokenIn, actuallyWithdrawn, address(this));
        // the withdrawal amount can deviate
        amountOut = exactInputToSelf(actuallyWithdrawn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        _transferERC20Tokens(params.path.getLastToken(), params.recipient, amountOut);
    }

    function withdrawAndSwapExactInToETH(CollateralWithdrawParamsMultiExactIn memory params) external returns (uint256 amountOut) {
        address tokenIn = params.path.getFirstToken();
        uint256 actuallyWithdrawn = params.amountIn;
        // withraw and send funds to this address for swaps
        _transferERC20TokensFrom(aas().aTokens[tokenIn], msg.sender, address(this), actuallyWithdrawn);
        actuallyWithdrawn = _aavePool.withdraw(tokenIn, actuallyWithdrawn, address(this));
        amountOut = exactInputToSelf(actuallyWithdrawn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        INativeWrapper(us().weth).withdraw(amountOut);
        payable(params.recipient).transfer(amountOut);
    }

    function withdrawAndSwapExactOut(CollateralParamsMultiExactOut calldata params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 14, interestRateMode: 0, exactIn: false});

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            msg.sender,
            zeroForOne,
            -params.amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to withdraw too much");
    }

    function withdrawAndSwapExactOutToETH(CollateralParamsMultiExactOut calldata params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint256 amountOut = params.amountOut;
        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 14, interestRateMode: 0, exactIn: false});
        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to withdraw too much");

        INativeWrapper(tokenOut).withdraw(amountOut);
        payable(msg.sender).transfer(amountOut);
    }

    function borrowAndSwapExactIn(MoneyMarketParamsMultiExactIn memory params) external returns (uint256 amountOut) {
        uint256 amountIn = params.amountIn;
        // borrow and send funds to this address for swaps
        _aavePool.borrow(params.path.getFirstToken(), amountIn, params.interestRateMode, 0, msg.sender);
        amountOut = exactInputToSelf(amountIn, params.path);
        IERC20(params.path.getLastToken()).transfer(params.recipient, amountOut);
        require(amountOut >= params.amountOutMinimum, "Received too little");
    }

    function borrowAndSwapExactInToETH(MoneyMarketParamsMultiExactIn calldata params) external returns (uint256 amountOut) {
        uint256 amountIn = params.amountIn;
        // borrow and send funds to this address for swaps
        _aavePool.borrow(params.path.getFirstToken(), amountIn, params.interestRateMode, 0, msg.sender);
        // swap exact in with common router
        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        INativeWrapper(us().weth).withdraw(amountOut);
        payable(params.recipient).transfer(amountOut);
    }

    function borrowAndSwapExactOut(MarginSwapParamsMultiExactOut memory params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint256 amountOut = params.amountOut;
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 13,
            interestRateMode: params.interestRateMode,
            exactIn: false
        });

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            msg.sender,
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );

        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to borrow too much");
    }

    function borrowAndSwapExactOutToETH(MarginSwapParamsMultiExactOut calldata params) external returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint256 amountOut = params.amountOut;
        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 13,
            interestRateMode: params.interestRateMode,
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

        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to borrow too much");

        INativeWrapper(us().weth).withdraw(amountOut);
        payable(msg.sender).transfer(amountOut);
    }

    function swapAndRepayExactIn(MoneyMarketParamsMultiExactIn calldata params) external returns (uint256 amountOut) {
        uint256 amountIn = params.amountIn;
        _transferERC20TokensFrom(params.path.getFirstToken(), msg.sender, address(this), amountIn);
        // swap to self
        amountOut = exactInputToSelf(amountIn, params.path);
        require(amountOut >= params.amountOutMinimum, "Received too little");
        // deposit received amount to aave on behalf of user
        amountOut = _aavePool.repay(params.path.getLastToken(), amountOut, params.interestRateMode, msg.sender);
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
        amountOut = _aavePool.repay(params.path.getLastToken(), amountOut, params.interestRateMode, msg.sender);
    }

    function swapAndRepayExactOut(MarginSwapParamsMultiExactOut memory params) external payable returns (uint256 amountIn) {
        (address tokenOut, address tokenIn, uint24 fee) = params.path.decodeFirstPool();
        uint256 amountOut = params.amountOut;
        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 12, interestRateMode: 0, exactIn: false});

        bool zeroForOne = tokenIn < tokenOut;
        _toPool(tokenIn, fee, tokenOut).swap(
            address(this),
            zeroForOne,
            -amountOut.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(data)
        );
        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        require(params.amountInMaximum >= amountIn, "Had to pay too much");

        // deposit received amount to aave on behalf of user
        _aavePool.repay(tokenOut, amountOut, params.interestRateMode, msg.sender);
    }

    function swapETHAndRepayExactOut(MarginSwapParamsMultiExactOut calldata params) external payable returns (uint256 amountIn) {
        INativeWrapper _weth = INativeWrapper(us().weth);
        uint256 amountReceived = params.amountInMaximum;
        _weth.deposit{value: amountReceived}();

        MarginCallbackData memory data = MarginCallbackData({path: params.path, tradeType: 12, interestRateMode: 0, exactIn: false});

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
        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        _aavePool.repay(tokenOut, amountOut, params.interestRateMode, msg.sender);
        // refund dust
        amountReceived -= amountIn;
        _weth.withdraw(amountReceived);
        payable(msg.sender).transfer(amountReceived);
    }
}
