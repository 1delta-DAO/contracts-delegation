// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {MarginTrading} from "./MarginTrading.sol";

// solhint-disable max-line-length

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
        bytes calldata path
    ) external payable {
        // we cache the address as bytes32
        gcs().cache = bytes32(bytes20(msg.sender));
        flashSwapExactOutInternal(amountOut, address(this), path);
        // retrieve cached amount and check slippage
        if (maximumAmountIn < uint256(gcs().cache)) revert Slippage();
        gcs().cache = 0x0;
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
        flashSwapExactOutInternal(amountOut, address(this), path);
        // retrieve cached amount and check slippage
        if (maximumAmountIn < uint256(gcs().cache)) revert Slippage();
        gcs().cache = 0x0;
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
        uint8 lenderId,
        bytes calldata path
    ) external payable {
        // we cache the address as bytes32
        gcs().cache = bytes32(bytes20(msg.sender));
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        address tokenOut;
        assembly {
            tokenOut := shr(96, calldataload(path.offset))
        }
        if (_interestRateMode == 2) _debtBalance = _callerVariableDebtBalance(tokenOut, lenderId);
        else _debtBalance = _callerStableDebtBalance(tokenOut, lenderId);
        if (_debtBalance == 0) revert NoBalance(); // revert if amount is zero

        flashSwapExactOutInternal(_debtBalance, address(this), path);
        if (maximumAmountIn < uint256(gcs().cache)) revert Slippage();
        gcs().cache = 0x0;
    }

    /**
     * @notice The same as swapAllOutSpot, except that the payer is this contract - used when wrapping ETH before calling
     */
    function swapAllOutSpotSelf(
        uint256 maximumAmountIn,
        uint256 interestRateMode,
        uint8 lenderId,
        bytes calldata path
    ) external payable {
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        address tokenOut;
        assembly {
            tokenOut := shr(96, calldataload(path.offset))
        }
        if (_interestRateMode == 2) _debtBalance = _callerVariableDebtBalance(tokenOut, lenderId);
        else _debtBalance = _callerStableDebtBalance(tokenOut, lenderId);
        if (_debtBalance == 0) revert NoBalance(); // revert if amount is zero

        flashSwapExactOutInternal(_debtBalance, address(this), path);
        if (maximumAmountIn < uint256(gcs().cache)) revert Slippage();
        gcs().cache = 0x0;
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
        uint256 amountIn = _balanceOfThis(tokenIn);
        if (amountIn == 0) revert NoBalance(); // revert if amount is zero
        uint256 amountOut = swapExactIn(amountIn, path);
        if (minimumAmountOut > amountOut) revert Slippage();
    }

    function _balanceOfThis(address underlying) private view returns (uint256 callerBalance) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            let collateralToken := sload(keccak256(ptr, 0x40))
            // selector for balanceOf(address)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(add(ptr, 0x4), address())

            // call to underlying
            pop(staticcall(gas(), underlying, ptr, 0x24, ptr, 0x20))

            callerBalance := mload(ptr)
        }
    }
}
