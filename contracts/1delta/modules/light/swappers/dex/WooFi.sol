// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../../shared/masks/Masks.sol";

/**
 * @title WooFi swapper contract
 */
abstract contract WooFiSwapper is ERC20Selectors, Masks {
    /// @dev WooFi rebate receiver
    address private constant REBATE_RECIPIENT = 0x0000000000000000000000000000000000000000;

    constructor() {}

    /**
     * Swaps exact input on WOOFi DEX
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 21     | 1              | pay flag             | <- 0: caller pays; 1: contract pays; greater: pre-funded
     */
    function swapWooFiExactIn(
        uint256 fromAmount,
        address tokenIn,
        address tokenOut,
        address receiver,
        uint256 currentOffset,
        address callerAddress
    ) internal returns (uint256 amountOut, uint256) {
        assembly {
            let ptr := mload(0x40)
            let pool := calldataload(currentOffset)
            let payFlag := and(UINT8_MASK, shr(88, pool))
            pool := shr(96, pool)
            switch payFlag
            case 0 {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), callerAddress)
                mstore(add(ptr, 0x24), pool)
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
                mstore(add(ptr, 0x04), pool)
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

            // selector for swap(address,address,uint256,uint256,address,address)
            mstore(
                ptr, //
                0x7dc2038200000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x04), tokenIn)
            mstore(add(ptr, 0x24), tokenOut)
            mstore(add(ptr, 0x44), fromAmount)
            mstore(add(ptr, 0x64), 0x0) // amountOutMin unused
            mstore(add(ptr, 0x84), receiver) // recipient
            mstore(add(ptr, 0xA4), REBATE_RECIPIENT) // rebateTo
            if iszero(
                call(
                    gas(),
                    pool,
                    0x0, // no native transfer
                    ptr,
                    0xC4, // input length 196
                    0x0, // store output here
                    0x20 // output is just uint
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            amountOut := mload(0x0)
            currentOffset := add(currentOffset, 21)
        }

        return (amountOut, currentOffset);
    }
}
