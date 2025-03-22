// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {BaseSwapper} from "./BaseSwapper.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice External call on whitelisted targets
 * This needs a whitelisting functions that stores the addresses in the correct slots
 * Do NOT whitlist lending contracts or tokens!
 */
abstract contract Swaps is BaseSwapper {
    function _swap(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        uint256 amountIn;
        address tokenIn;
        uint256 swapsMaxIndex;
        uint256 splitsMaxIndex;
        /*
         * Store the data for the callback as follows
         * | Offset | Length (bytes) | Description          |
         * |--------|----------------|----------------------|
         * | 0      | 16             | amount               |
         * | 16     | 20             | tokenIn              |
         * | 36     | any            | data                 |
         *
         * `data` is a path that can break down in aritrary sub paths:
         * | Offset | Length (bytes) | Description          |
         * |--------|----------------|----------------------|
         * | 0      | 1              | swapCount-1          |
         * | 1      | any            | eSwapData            |
         */
        assembly {
            amountIn := and(UINT120_MASK, shr(128, calldataload(currentOffset)))
            currentOffset := add(currentOffset, 16)
            let dataStart := calldataload(currentOffset)
            tokenIn := shr(96, dataStart)
            currentOffset := add(20, currentOffset)
        }
        (amountIn, currentOffset, ) = _multihopSplitSwap(
            amountIn,
            0,
            tokenIn,
            callerAddress,
            currentOffset //
        );
        return currentOffset;
    }
}
