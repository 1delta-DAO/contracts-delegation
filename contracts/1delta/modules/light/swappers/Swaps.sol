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
        assembly {
            // get first 2 addresses
            tokenIn := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            tokenOut := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }
        uint amountIn = 10000;
        (amountIn, currentOffset) = _eSwapExactIn(
            amountIn,
            tokenIn,
            tokenOut,
            callerAddress,
            address(this),
            currentOffset //
        );
        return currentOffset;
    }
}
