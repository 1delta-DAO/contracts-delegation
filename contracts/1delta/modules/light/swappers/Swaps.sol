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
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        address receiver;
        assembly {
            amountIn := shr(128, calldataload(currentOffset))
            currentOffset := add(currentOffset, 16)
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
        return currentOffset;
    }
}
