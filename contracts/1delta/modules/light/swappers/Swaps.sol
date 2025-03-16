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
        uint256 swapsCount;
        /*
         * Store the data for the callback as follows
         * | Offset | Length (bytes) | Description          |
         * |--------|----------------|----------------------|
         * | 0      | 1              | swapCount            |
         * | 1      | 16             | amount               |
         * | 17     | 20             | tokenOut             |
         * | 37     | 20             | tokenIn              |
         */
        assembly {
            amountIn := calldataload(currentOffset)
            swapsCount := shr(248, amountIn)
            amountIn := and(UINT120_MASK, shr(120, calldataload(currentOffset)))
            currentOffset := add(currentOffset, 17)
        }
        uint256 i;
        while (true) {
            address tokenIn;
            address tokenOut;
            address receiver;
            assembly {
                // get first 2 addresses
                tokenIn := shr(96, calldataload(currentOffset))
                currentOffset := add(currentOffset, 20)
                tokenOut := shr(96, calldataload(currentOffset))
                currentOffset := add(currentOffset, 20)
                receiver := shr(96, calldataload(currentOffset))
                currentOffset := add(currentOffset, 20)
            }
            (amountIn, currentOffset) = _eSwapExactIn(
                amountIn,
                tokenIn,
                tokenOut,
                callerAddress,
                receiver,
                currentOffset //
            );
            // break criteria
            if (i == swapsCount) {
                break;
            } else {
                i++;
            }
        }
        return currentOffset;
    }
}
