// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../../shared/masks/Masks.sol";

/**
 * @title LB swapper contract
 */
abstract contract LBSwapper is ERC20Selectors, Masks {
    /**
     * Swaps exact input on LB
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 1              | pay flag             | <- 0: caller pays; 1: contract pays; greater: pre-funded
     */
    function swapLBexactIn(
        uint256 fromAmount,
        address tokenIn,
        address tokenOut,
        address receiver,
        address callerAddress,
        uint256 currentOffset //
    ) internal returns (uint256 amountOut, uint256) {
        assembly {
            let lbData := calldataload(currentOffset)
            let pair := shr(96, lbData)

            let ptr := mload(0x40)
            switch and(UINT8_MASK, shr(72, lbData))
            case 0 {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), callerAddress)
                mstore(add(ptr, 0x24), pair)
                mstore(add(ptr, 0x44), fromAmount)

                let success := call(gas(), tokenIn, 0, ptr, 0x64, 0, 32)

                let rdsize := returndatasize()
                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            gt(rdsize, 31), // at least 32 bytes
                            eq(mload(0), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
            // transfer plain
            case 1 {
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), pair)
                mstore(add(ptr, 0x24), fromAmount)
                let success := call(gas(), tokenIn, 0, ptr, 0x44, 0, 32)

                let rdsize := returndatasize()
                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            gt(rdsize, 31), // at least 32 bytes
                            eq(mload(0), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }

            // getTokenY()
            mstore(0x0, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            if iszero(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pair,
                    0x0,
                    0x4, // selector only
                    0x0,
                    0x20
                )
            ) {
                revert(0, 0)
            }
            let swapForY := eq(tokenOut, mload(0x0))
            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////

            // swap(bool,address)
            mstore(ptr, 0x53c059a000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), swapForY)
            mstore(add(ptr, 0x24), receiver)
            // call swap, revert if invalid/undefined pair
            if iszero(call(gas(), pair, 0x0, ptr, 0x44, ptr, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // the swap call returns both amounts encoded into a single bytes32 as (amountX,amountY)
            switch swapForY
            case 0 {
                amountOut := and(mload(ptr), 0xffffffffffffffffffffffffffffffff)
            }
            default {
                amountOut := shr(128, mload(ptr))
            }

            currentOffset := add(currentOffset, 21)
        }
        return (amountOut, currentOffset);
    }
}
