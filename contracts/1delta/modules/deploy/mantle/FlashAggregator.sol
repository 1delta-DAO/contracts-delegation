// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.25;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {MarginTrading} from "./MarginTrading.sol";

// solhint-disable max-line-length

/**
 * @title FlashAggregator
 * @notice Adds money market and default transfer functions to margin trading
 */
contract DeltaFlashAggregatorMantle is MarginTrading {
    // constants
    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;
    address private constant DEFAULT_ADDRESS_CACHED = address(0);

    constructor() {}

    /**
     * @notice This flash swap allows either a direct withdrawal or borrow, or can just be paid by the user
     * Has to be batch-called togehter with a sweep, deposit or repay function.
     * The flash swap will pull the funds directly from the user
     */
    function swapExactOutSpot(
        uint256 amountOut,
        uint256 maximumAmountIn,
        bytes calldata path
    ) external payable {
        acs().cachedAddress = msg.sender;
        flashSwapExactOutInternal(amountOut, address(this), path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
    }

    /**
     * @notice Same as swapExactOutSpot, except that the payer is this contract.
     */
    function swapExactOutSpotSelf(
        uint256 amountOut,
        uint256 maximumAmountIn,
        bytes calldata path
    ) external payable {
        flashSwapExactOutInternal(amountOut, address(this), path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
    }

    /**
     * @notice A simple exact input spot swap using internal callbacks.
     * Has to be batch-called with transfer in / sweep functions
     * Requires that the funds already have been transferred to this contract
     */
    function swapExactInSpot(
        uint256 amountIn,
        uint256 minimumAmountOut,
        bytes calldata path
    ) external payable {
        uint256 amountOut = swapExactIn(amountIn, path);
        if (minimumAmountOut > amountOut) revert Slippage();
    }

    /**
     * @notice The same as swapExactOutSpot, except that we snipe the debt balance
     * This ensures that no borrow dust will be left. The next step in the batch has to the repay function.
     */
    function swapAllOutSpot(
        uint256 maximumAmountIn,
        uint256 interestRateMode,
        bytes calldata path
    ) external payable {
        acs().cachedAddress = msg.sender;
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        address tokenOut;
        assembly {
            tokenOut := shr(96, calldataload(path.offset))
        }
        if (_interestRateMode == 2) _debtBalance = _balanceOf(aas().vTokens[tokenOut], msg.sender);
        else _debtBalance = _balanceOf(aas().sTokens[tokenOut], msg.sender);
        if (_debtBalance == 0) revert NoBalance(); // revert if amount is zero

        flashSwapExactOutInternal(_debtBalance, address(this), path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
    }

    /**
     * @notice The same as swapAllOutSpot, except that the payer is this contract - used when wrapping ETH before calling
     */
    function swapAllOutSpotSelf(
        uint256 maximumAmountIn,
        uint256 interestRateMode,
        bytes calldata path
    ) external payable {
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        address tokenOut;
        assembly {
            tokenOut := shr(96, calldataload(path.offset))
        }
        if (_interestRateMode == 2) _debtBalance = _balanceOf(aas().vTokens[tokenOut], msg.sender);
        else _debtBalance = _balanceOf(aas().sTokens[tokenOut], msg.sender);
        if (_debtBalance == 0) revert NoBalance(); // revert if amount is zero

        flashSwapExactOutInternal(_debtBalance, address(this), path);
        if (maximumAmountIn < ncs().amount) revert Slippage();
        ncs().amount = DEFAULT_AMOUNT_CACHED;
    }

    /**
     * @notice The same as swapExactInSpot, except that we swap the entire balance
     * This function can be used after a withdrawal - to make sure that no dust is left
     */
    function swapAllInSpot(uint256 minimumAmountOut, bytes calldata path) external payable {
        address tokenIn;
        assembly {
            tokenIn := shr(96, calldataload(path.offset))
        }
        uint256 amountIn = _balanceOf(tokenIn, address(this));
        if (amountIn == 0) revert NoBalance(); // revert if amount is zero
        uint256 amountOut = swapExactIn(amountIn, path);
        if (minimumAmountOut > amountOut) revert Slippage();
    }
}
