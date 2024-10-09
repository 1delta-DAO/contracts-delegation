// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.27;

import {UniTypeSwapper} from "./UniType.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

/**
 * @title Uniswap V2 type swapper contract
 * @notice We do everything UniV2 here, incl Solidly, FoT, exactIn and -Out
 */
abstract contract SyncSwapper is UniTypeSwapper {
    /// @dev selector for swap(bytes,address,address,bytes)
    bytes32 internal constant SYNCSWAP_SELECTOR = 0x7132bb7f00000000000000000000000000000000000000000000000000000000;

    uint256 internal constant MAX_SINGLE_LENGTH_SYNCSWAP = 64;
    uint256 internal constant SKIP_LENGTH_SYNCSWAP = 42; // = 20+1+1+20

    constructor() {}

    /**
     * Executes an exact input swap internally across major syncSwap forks
     * Their callbacks are not flash swap callbacks and therefore cannot be used for
     * margin.
     */
    function swapSyncExactIn(address receiver, uint256 pathOffset) internal returns (uint256 buyAmount) {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for swap(...)
            mstore(ptr, SYNCSWAP_SELECTOR)
            mstore(add(ptr, 4), 0x80) // first param set offset
            mstore(add(ptr, 36), 0x0) // sender address
            ////////////////////////////////////////////////////
            // We store the bytes length to zero (no callback)
            // and directly trigger the swap
            ////////////////////////////////////////////////////
            mstore(add(ptr, 68), 0x0) // callback receiver address
            mstore(add(ptr, 100), 0x100) // calldata offset
            mstore(add(ptr, 132), 0x60) // datalength
            mstore(add(ptr, 164), shr(96, calldataload(pathOffset))) // tokenIn
            mstore(add(ptr, 196), receiver) // to
            mstore(add(ptr, 228), 0) // withdraw mode
            mstore(add(ptr, 260), 0) // path length is zero

            if iszero(
                call(
                    gas(),
                    shr(96, calldataload(add(pathOffset, 22))), // pair
                    0x0,
                    ptr, // input selector
                    292, // input size = 164 (selector (4bytes) plus 5*32bytes)
                    ptr, // output
                    0x40 // output size = 0x40
                )
            ) {
                // Forward the error
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            buyAmount := mload(add(ptr, 0x20))
        }
    }
}
