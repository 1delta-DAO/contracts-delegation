// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";

/**
 * @title Uniswap V2 type swapper contract
 * @notice We do everything UniV2 here, incl Solidly, FoT, exactIn and -Out
 */
abstract contract V2TypeGeneric is ERC20Selectors, Masks {
    /// @dev used for some of the denominators in solidly calculations
    uint256 private constant SCALE_18 = 1.0e18;

    ////////////////////////////////////////////////////
    // Uni V2 type selctors
    ////////////////////////////////////////////////////

    /// @dev selector for getReserves()
    bytes32 private constant UNI_V2_GET_RESERVES = 0x0902f1ac00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for swap(...)
    bytes32 private constant UNI_V2_SWAP = 0x022c0d9f00000000000000000000000000000000000000000000000000000000;

    /*
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 52     | 20             | pool                 |
     * | 94     | 2              | feeDenom             |
     * | 96     | 2              | calldataLength       | <-- 0: pay from self; 1: caller pays; 3: pre-funded;
     * | 98     | calldataLength | calldata             |
     */
    function _swapUniswapV2PoolExactInGeneric(
        uint256 dexId,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address receiver,
        uint256 currentOffset,
        address callerAddress
    ) internal returns (uint256 buyAmount, uint256) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            ////////////////////////////////////////////////////
            // We extract all relevant data from the path bytes blob
            ////////////////////////////////////////////////////
            let pool := calldataload(currentOffset)
            let clLength := and(UINT16_MASK, shr(64, pool))

            // Compute the buy amount based on the pair reserves.

            let zeroForOne := lt(
                tokenIn,
                tokenOut //
            )
            // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
            // buyAmount = (pairSellAmount * feeAm * buyReserve) /
            //     (pairSellAmount * feeAm + sellReserve * 1000);
            switch lt(dexId, 120)
            case 1 {
                // this is expected to be 10000 - x, where x is the poolfee in bps
                let poolFeeDenom := and(shr(80, pool), UINT16_MASK)
                pool := shr(96, pool)

                // Call pair.getReserves(), store the results in scrap space
                mstore(0x0, UNI_V2_GET_RESERVES)
                if iszero(staticcall(gas(), pool, 0x0, 0x4, 0x0, 0x40)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                // Revert if the pair contract does not return at least two words.
                if lt(returndatasize(), 0x40) {
                    revert(0, 0)
                }

                let reserveIn
                switch zeroForOne
                case 1 {
                    // Transpose if pair order is different.
                    buyAmount := mload(0x20)
                    reserveIn := mload(0x0)
                }
                default {
                    reserveIn := mload(0x20)
                    buyAmount := mload(0x0)
                }

                // compute out amount
                poolFeeDenom := mul(amountIn, poolFeeDenom)
                buyAmount := div(
                    mul(poolFeeDenom, buyAmount),
                    add(poolFeeDenom, mul(reserveIn, 10000)) //
                )
            }
            // all solidly-based protocols
            default {
                // we ignore the fee denominator for solidly type DEXs
                pool := shr(96, pool)
                // selector for getAmountOut(uint256,address)
                mstore(ptr, 0xf140a35a00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), amountIn)
                mstore(add(ptr, 0x24), tokenIn)
                if iszero(staticcall(gas(), pool, ptr, 0x44, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                buyAmount := mload(ptr)
            }

            ////////////////////////////////////////////////////
            // Prepare the swap tx
            ////////////////////////////////////////////////////

            // selector for swap(...)
            mstore(ptr, UNI_V2_SWAP)

            switch zeroForOne
            case 0 {
                mstore(add(ptr, 4), buyAmount)
                mstore(add(ptr, 36), 0)
            }
            default {
                mstore(add(ptr, 4), 0)
                mstore(add(ptr, 36), buyAmount)
            }
            mstore(add(ptr, 68), receiver)
            mstore(add(ptr, 100), 0x80) // bytes offset

            ////////////////////////////////////////////////////
            // In case of a flash swap, we copy the calldata to
            // the execution parameters
            ////////////////////////////////////////////////////
            switch lt(clLength, 3)
            case 0 {
                let plStored := add(clLength, 63)
                /*
                 * Store the data for the callback as follows
                 * | Offset | Length (bytes) | Description          |
                 * |--------|----------------|----------------------|
                 * | 0      | 20             | caller               |
                 * | 20     | 20             | tokenIn              |
                 * | 40     | 20             | tokenOut             |
                 * | 60     | 1              | dexId                |
                 * | 61     | 2              | calldataLength       |
                 * | 63     | calldataLength | calldata             |
                 */
                mstore(add(ptr, 132), shl(96, callerAddress))
                mstore(add(ptr, 152), shl(96, tokenIn))
                mstore(add(ptr, 172), shl(96, tokenOut))
                mstore8(add(ptr, 173), dexId)
                mstore(add(ptr, 174), shl(240, clLength)) // calldataLength (within bytes)
                // Store path
                calldatacopy(add(ptr, 176), currentOffset, clLength)
                if iszero(
                    call(
                        gas(),
                        pool,
                        0x0,
                        ptr, // input selector
                        add(0xA4, plStored), // input size = 164 (selector (4bytes) plus 5*32bytes)
                        0x0, // output = 0
                        0x0 // output size = 0
                    )
                ) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            ////////////////////////////////////////////////////
            // Otherwise, we have to assume that payment needs to
            // be facilitated outside the callback
            // 0: caller pays
            // 1: pay self
            // 2: the swap is pre-funded
            //    the operator needs to ensure that `amountIn`
            //    was already sent to the pool
            ////////////////////////////////////////////////////
            default {
                switch clLength
                case 0 {
                    // selector for transferFrom(address,address,uint256)
                    mstore(ptr, ERC20_TRANSFER_FROM)
                    mstore(add(ptr, 0x04), callerAddress)
                    mstore(add(ptr, 0x24), pool)
                    mstore(add(ptr, 0x44), amountIn)

                    zeroForOne := call(gas(), tokenIn, 0, ptr, 0x64, 0, 32)

                    pool := returndatasize()
                    // Check for ERC20 success. ERC20 tokens should return a boolean,
                    // but some don't. We accept 0-length return data as success, or at
                    // least 32 bytes that starts with a 32-byte boolean true.
                    zeroForOne := and(
                        zeroForOne, // call itself succeeded
                        or(
                            iszero(pool), // no return data, or
                            and(
                                gt(pool, 31), // at least 32 bytes
                                eq(mload(0), 1) // starts with uint256(1)
                            )
                        )
                    )

                    if iszero(zeroForOne) {
                        returndatacopy(0, 0, pool)
                        revert(0, pool)
                    }
                }
                // transfer plain
                case 1 {
                    // selector for transfer(address,uint256)
                    mstore(ptr, ERC20_TRANSFER)
                    mstore(add(ptr, 0x04), pool)
                    mstore(add(ptr, 0x24), amountIn)
                    zeroForOne := call(gas(), tokenIn, 0, ptr, 0x44, 0, 32)
                    pool := returndatasize()
                    // Check for ERC20 success. ERC20 tokens should return a boolean,
                    // but some don't. We accept 0-length return data as success, or at
                    // least 32 bytes that starts with a 32-byte boolean true.
                    zeroForOne := and(
                        zeroForOne, // call itself succeeded
                        or(
                            iszero(pool), // no return data, or
                            and(
                                gt(pool, 31), // at least 32 bytes
                                eq(mload(0), 1) // starts with uint256(1)
                            )
                        )
                    )

                    if iszero(zeroForOne) {
                        returndatacopy(0, 0, pool)
                        revert(0, pool)
                    }
                }
                ////////////////////////////////////////////////////
                // We store the bytes length to zero (no callback)
                // and directly trigger the swap
                ////////////////////////////////////////////////////
                mstore(add(ptr, 0x84), 0) // bytes length
                if iszero(
                    call(
                        gas(),
                        pool,
                        0x0,
                        ptr, // input selector
                        0xA4, // input size = 164 (selector (4bytes) plus 5*32bytes)
                        0, // output = 0
                        0 // output size = 0
                    )
                ) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }

            switch lt(clLength, 3)
            case 1 {
                currentOffset := add(currentOffset, 24)
            }
            default {
                currentOffset := add(currentOffset, add(24, clLength))
            }
        }
        return (buyAmount, currentOffset);
    }

    /**
     * Executes an exact input swap internally across major UniV2 forks supporting
     * FOT tokens. Will only be used at the begining of a swap path where users sell a FOT token
     * Due to the nature of the V2 impleemntation, the callback is not triggered if no calldata is provided
     * As such, we never enter the callback implementation when using this function
     * @param amountIn sell amount
     * @return buyAmount output amount
     */
    function swapUniV2ExactInFOTGeneric(uint256 amountIn, address receiver, uint256 pathOffset) internal returns (uint256 buyAmount) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            ////////////////////////////////////////////////////
            // We extract all relevant data from the path bytes blob
            ////////////////////////////////////////////////////
            let pair := calldataload(add(pathOffset, 22))
            // this is expected to be 10000 - x, where x is the poolfee in bps
            let poolFeeDenom := and(shr(80, pair), UINT16_MASK)
            pair := shr(96, pair)
            // we define this as token in and later re-assign this to
            // reserve in to prevent stack too deep errors
            let tokenIn := shr(96, calldataload(pathOffset))
            // Compute the buy amount based on the pair reserves.
            {
                let zeroForOne := lt(
                    tokenIn,
                    and(ADDRESS_MASK, calldataload(add(pathOffset, 32))) // tokenOut
                )
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                // Call pair.getReserves(), store the results in scrap space
                mstore(0x0, UNI_V2_GET_RESERVES)
                if iszero(staticcall(gas(), pair, 0x0, 0x4, 0x0, 0x40)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                // Revert if the pair contract does not return at least two words.
                if lt(returndatasize(), 0x40) {
                    revert(0, 0)
                }
                let sellReserve
                switch zeroForOne
                case 1 {
                    // Transpose if pair order is different.
                    sellReserve := mload(0x0)
                    buyAmount := mload(0x20)
                }
                default {
                    sellReserve := mload(0x20)
                    buyAmount := mload(0x0)
                }
                // call tokenIn.balanceOf(pair)
                mstore(0x0, ERC20_BALANCE_OF)
                mstore(0x4, pair)
                // we store the result
                pop(staticcall(gas(), tokenIn, 0x0, 0x24, 0x0, 0x20))
                amountIn := sub(mload(0x0), sellReserve)

                // adjustment via denominator
                poolFeeDenom := mul(amountIn, poolFeeDenom)
                buyAmount := div(mul(poolFeeDenom, buyAmount), add(poolFeeDenom, mul(sellReserve, 10000)))

                ////////////////////////////////////////////////////
                // Prepare the swap tx
                ////////////////////////////////////////////////////

                // selector for swap(...)
                mstore(ptr, UNI_V2_SWAP)

                switch zeroForOne
                case 0 {
                    mstore(add(ptr, 0x4), buyAmount)
                    mstore(add(ptr, 0x24), 0)
                }
                default {
                    mstore(add(ptr, 0x4), 0)
                    mstore(add(ptr, 0x24), buyAmount)
                }
                mstore(add(ptr, 0x44), receiver)
                mstore(add(ptr, 0x64), 0x80) // bytes offset

                ////////////////////////////////////////////////////
                // We store the bytes length to zero (no callback)
                // and directly trigger the swap
                ////////////////////////////////////////////////////
                mstore(add(ptr, 0x84), 0) // bytes length
                if iszero(
                    call(
                        gas(),
                        pair,
                        0x0,
                        ptr, // input selector
                        0xA4, // input size = 164 (selector (4bytes) plus 5*32bytes)
                        0, // output = 0
                        0 // output size = 0
                    )
                ) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
    }
}
