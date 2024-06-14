// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {MarginTrading} from "./MarginTrading.sol";

/**
 * Aggregator contract that directly exposes spot trading functions
 * Ideal for gas savings when not using split routes
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
        swapExactOutInternal(amountOut, maximumAmountIn, msg.sender, receiver, path);
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
        uint256 dexId = _preFundTrade(msg.sender, amountIn, path);
        uint256 amountOut = swapExactIn(amountIn, dexId, msg.sender, receiver, path);
        // slippage check
        assembly {
            if lt(amountOut, minimumAmountOut) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
        }
    }
}
