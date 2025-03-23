// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../../shared/masks/Masks.sol";

/**
 * @title DodoV2 swapper contract
 */
abstract contract DodoV2Swapper is ERC20Selectors, Masks {
    /**
     * Swaps exact input on WOOFi DEX
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 1              | sellQuote            |
     * | 21     | 2              | pay flag             | <- 0: caller pays; 1: contract pays; greater: pre-funded
     */
    function _swapDodoV2ExactIn(
        uint256 fromAmount,
        address tokenIn,
        address receiver,
        address callerAddress,
        uint256 currentOffset
    ) internal returns (uint256 amountOut, uint256) {
        assembly {
            let dodoData := calldataload(currentOffset)
            let pool := shr(96, dodoData)

            switch and(UINT8_MASK, shr(72, dodoData))
            case 0 {
                let ptr := mload(0x40)
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
                let ptr := mload(0x40)
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

            // determine selector
            switch and(UINT8_MASK, shr(88, dodoData))
            case 0 {
                // sellBase
                mstore(0x0, 0xbd6015b400000000000000000000000000000000000000000000000000000000)
            }
            default {
                // sellQuote
                mstore(0x0, 0xdd93f59a00000000000000000000000000000000000000000000000000000000)
            }
            mstore(0x4, receiver)
            // call swap, revert if invalid/undefined pair
            if iszero(call(gas(), pool, 0x0, 0x0, 0x24, 0x0, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // the swap call returns the output amount directly
            amountOut := mload(0x0)
            currentOffset := add(23, currentOffset)
        }
        return (amountOut, currentOffset);
    }
}
