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
        uint256 minimumAmountReceived;
        address tokenIn;
        /*
         * Store the data for the callback as follows
         * | Offset | Length (bytes) | Description          |
         * |--------|----------------|----------------------|
         * | 0      | 16             | amount               | <-- input amount
         * | 16     | 16             | amountMax            | <-- slippage check
         * | 32     | 20             | tokenIn              |
         * | 52     | any            | data                 |
         *
         * `data` is a path matrix definition (see BaseSwapepr)
         */
        assembly {
            minimumAmountReceived := calldataload(currentOffset)
            amountIn := and(UINT120_MASK, shr(128, minimumAmountReceived))
            minimumAmountReceived := and(UINT128_MASK, minimumAmountReceived)
            currentOffset := add(currentOffset, 32)
            let dataStart := calldataload(currentOffset)
            tokenIn := shr(96, dataStart)
            currentOffset := add(20, currentOffset)
        }
        (amountIn, currentOffset, ) = _singleSwapSplitOrRoute(
            amountIn,
            tokenIn,
            callerAddress,
            currentOffset //
        );

        assembly {
            if gt(minimumAmountReceived, amountIn) {
                mstore(0x0, SLIPPAGE)
                revert(0x0, 0x4)
            }
        }
        return currentOffset;
    }
}
