// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {MarginTrading} from "./MarginTrading.sol";

/**
 * @title FlashAggregator
 * @notice Adds spot trading functions to general margin trading
 */
contract DeltaFlashAggregatorMantle is MarginTrading {

    constructor() MarginTrading() {}

    /**
     * @notice Has to be batch-called togehter with a sweep, deposit or repay function.
     * The flash swap will pull the funds directly from the user
     */
    function swapExactOutSpot(
        uint256 amountOut,
        uint256 maximumAmountIn,
        address receiver,
        bytes calldata path
    ) external payable {
        flashSwapExactOutInternal(amountOut, receiver, msg.sender, path);
        // slippage check
        assembly {
            let amountIn := sload(NUMBER_CACHE_SLOT)
            if gt(amountIn, maximumAmountIn) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
            // reset cache
            sstore(NUMBER_CACHE_SLOT, DEFAULT_CACHE)
        }
    }

    /**
     * @notice Same as swapExactOutSpot, except that the payer is this contract.
     */
    function swapExactOutSpotSelf(
        uint256 amountOut,
        uint256 maximumAmountIn,
        bytes calldata path
    ) external payable {
        // we do not need to cache anything in this case
        flashSwapExactOutInternal(amountOut, address(this), address(this), path);
        // slippage check
        assembly {
            let amountIn := sload(NUMBER_CACHE_SLOT)
            if gt(amountIn, maximumAmountIn) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
            // reset cache
            sstore(NUMBER_CACHE_SLOT, DEFAULT_CACHE)
        }
    }

    /**
     * @notice A simple exact input spot swap using internal callbacks. 
     * Variant that can be called as is provided the path tradeId starts with 10
     */
    function swapExactInSpot(
        uint256 amountIn,
        uint256 minimumAmountOut,
        address receiver,
        bytes calldata path
    ) external payable {
        uint256 amountOut = swapExactIn(amountIn, receiver, msg.sender, path);
        // slippage check
        assembly {
            if lt(amountOut, minimumAmountOut) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
        }
    }

    /**
     * @notice A simple exact input spot swap using internal callbacks.
     * Has to be batch-called with transfer in / sweep functions
     * Requires that the funds already have been transferred to this contract
     */
    function swapExactInSpotSelf(
        uint256 amountIn,
        uint256 minimumAmountOut,
        bytes calldata path
    ) external payable {
        uint256 amountOut = swapExactIn(amountIn, msg.sender, address(this), path);
        // slippage check
        assembly {
            if lt(amountOut, minimumAmountOut) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
        }
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
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        address tokenOut;
        assembly {
            tokenOut := shr(96, calldataload(path.offset))
        }
        if (_interestRateMode == 2) _debtBalance = _variableDebtBalance(tokenOut, msg.sender, getLender(path));
        else _debtBalance = _stableDebtBalance(tokenOut, msg.sender, getLender(path));
        if (_debtBalance == 0) revert NoBalance(); // revert if amount is zero

        flashSwapExactOutInternal(_debtBalance, address(this), msg.sender, path);
        // slippage check
        assembly {
            let amountIn := sload(NUMBER_CACHE_SLOT)
            if gt(amountIn, maximumAmountIn) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
            // reset cache
            sstore(NUMBER_CACHE_SLOT, DEFAULT_CACHE)
        }
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
        if (_interestRateMode == 2) _debtBalance = _variableDebtBalance(tokenOut, msg.sender, getLender(path));
        else _debtBalance = _stableDebtBalance(tokenOut, msg.sender, getLender(path));
        if (_debtBalance == 0) revert NoBalance(); // revert if amount is zero

        flashSwapExactOutInternal(_debtBalance, address(this), address(this), path);
        // slippage check
        assembly {
            let amountIn := sload(NUMBER_CACHE_SLOT)
            if gt(amountIn, maximumAmountIn) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
            // reset cache
            sstore(NUMBER_CACHE_SLOT, DEFAULT_CACHE)
        }
    }

    /**
     * @notice The same as swapExactInSpot, except that we swap the entire balance
     * This function can be used after a withdrawals and other operations that
     * transfer into this contract
     *  - to make sure that no dust is left
     */
    function swapAllInSpot(uint256 minimumAmountOut, bytes calldata path) external payable {
        address tokenIn;
        assembly {
            tokenIn := shr(96, calldataload(path.offset))
        }
        uint256 amountIn = _balanceOfThis(tokenIn);
        if (amountIn == 0) revert NoBalance(); // revert if amount is zero
        uint256 amountOut = swapExactIn(amountIn, msg.sender, msg.sender, path);
        // slippage check
        assembly {
            if lt(amountOut, minimumAmountOut) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
        }
    }
}
