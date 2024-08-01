// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {UniTypeSwapper} from "./UniType.sol";

// solhint-disable max-line-length

/**
 * @title Base swapper contract
 * @notice Contains basic logic for swap executions with DEXs
 */
abstract contract CurveSwapper is UniTypeSwapper {
    /** Standard curve pool selectors */

    // exchange(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE = 0x5b41b90800000000000000000000000000000000000000000000000000000000;
    // exchange_underlying(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE_UNDERLYING = 0xa6417ed600000000000000000000000000000000000000000000000000000000;
    // exchange_underlying(uint256,uint256,uint256,uint256,address)
    bytes32 private constant EXCHANGE_UNDERLYING_RECEIVER = 0xe2ad025a00000000000000000000000000000000000000000000000000000000;

    /** Meta pool zap selectors - first argument is another curve pool */

    // exchange(address,uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE_META = 0x64a1455800000000000000000000000000000000000000000000000000000000;
    // exchange(address,uint256,uint256,uint256,uint256,bool,address)
    bytes32 private constant EXCHANGE_META_RECEIVER = 0xb837cc6900000000000000000000000000000000000000000000000000000000;

    constructor() {}

    /**
     * Swaps using a meta pool (i.e. a curve pool that has another one as underlying)
     * We first swap normally to the metapool and the call `remove_liquidity_one_coin`
     * to get the desired output coin.
     * Wa assume that everything is pre-parametrized (meta:i,j,dx;pool:i,j)
     * Data is supposed to be packed as follows
     * tokenIn | actionId | dexId | metaPool | sm | i | j | pool | tokenOut
     * sm is the selecor,
     * i,j are the swap indexes for the meta pool
     * sp is the selector for for the regular pool
     * k is the withdraw index for the regular pool
     */
    function swapCurveMeta(
        uint256 pathOffset,
        uint256 amountIn,
        address payer,
        address receiver //
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // Pull funds if needed
            ////////////////////////////////////////////////////
            if xor(payer, address()) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(
                    gas(),
                    and(
                        ADDRESS_MASK,
                        shr(96, calldataload(pathOffset)) // tokenIn
                    ),
                    0,
                    ptr,
                    0x64,
                    ptr,
                    32
                )

                let rdsize := returndatasize()

                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            iszero(lt(rdsize, 32)), // at least 32 bytes
                            eq(mload(ptr), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }

            let indexData := calldataload(add(pathOffset, 22))
            let metaPool := and(shr(96, indexData), ADDRESS_MASK)
            let selectorId := and(shr(88, indexData), 0xff)

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////

            // populate swap selector
            switch selectorId
            case 0 {
                // we can do it so that the receiver is incldued
                // in the call
                mstore(ptr, EXCHANGE_META_RECEIVER)
                mstore(
                    add(ptr, 0x4),
                    and(shr(96, calldataload(add(pathOffset, 45))), ADDRESS_MASK) // pool
                )
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff)) // indexIn
                mstore(add(ptr, 0x44), and(shr(72, indexData), 0xff)) // indexOut
                mstore(add(ptr, 0x64), amountIn)
                mstore(add(ptr, 0x84), 0) // min out is zero, we validate slippage at the end
                mstore(add(ptr, 0xA4), 0) // useEth=false
                mstore(add(ptr, 0xC4), receiver)
                if iszero(call(gas(), metaPool, 0x0, ptr, 0xE4, ptr, 0x20)) {
                    let rdsize := returndatasize()
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
                amountOut := mload(ptr)
            }
            default {
                // otherwise, the reciever is this contract
                mstore(ptr, EXCHANGE_META)
                mstore(
                    add(ptr, 0x4),
                    and(shr(96, calldataload(add(pathOffset, 45))), ADDRESS_MASK) // pool
                )
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff)) // indexIn
                mstore(add(ptr, 0x44), and(shr(72, indexData), 0xff))  // indexOut
                mstore(add(ptr, 0x64), amountIn)
                mstore(add(ptr, 0x84), 0) // min out is zero, we validate slippage at the end
                if iszero(call(gas(), metaPool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                    let rdsize := returndatasize()
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
                amountOut := mload(ptr)
                ////////////////////////////////////////////////////
                // Send funds to receiver if needed
                ////////////////////////////////////////////////////
                if xor(receiver, address()) {
                    // selector for transfer(address,uint256)
                    mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), receiver)
                    mstore(add(ptr, 0x24), amountOut)
                    let success := call(
                        gas(),
                        and(
                            ADDRESS_MASK,
                            shr(96, calldataload(add(pathOffset, 44))) // tokenIn, added 2x addr + 4x uint8
                        ),
                        0,
                        ptr,
                        0x44,
                        ptr,
                        32
                    )

                    let rdsize := returndatasize()

                    // Check for ERC20 success. ERC20 tokens should return a boolean,
                    // but some don't. We accept 0-length return data as success, or at
                    // least 32 bytes that starts with a 32-byte boolean true.
                    success := and(
                        success, // call itself succeeded
                        or(
                            iszero(rdsize), // no return data, or
                            and(
                                iszero(lt(rdsize, 32)), // at least 32 bytes
                                eq(mload(ptr), 1) // starts with uint256(1)
                            )
                        )
                    )

                    if iszero(success) {
                        returndatacopy(0, 0, rdsize)
                        revert(0, rdsize)
                    }
                }
            }
        }
    }

    /**
     * Swaps using a meta pool (i.e. a curve pool that has another one as underlying)
     * We first swap normally to the metapool and the call `remove_liquidity_one_coin`
     * to get the desired output coin.
     * Wa assume that everything is pre-parametrized (meta:i,j,dx;pool:i,j)
     * Data is supposed to be packed as follows
     * tokenIn | actionId | dexId | pool | sm | i | j | tokenOut
     * sm is the selecor,
     * i,j are the swap indexes for the pool
     */
    function swapCurveGeneral(
        uint256 pathOffset,
        uint256 amountIn,
        address payer,
        address receiver //
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // Pull funds if needed
            ////////////////////////////////////////////////////
            if xor(payer, address()) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(
                    gas(),
                    and(
                        ADDRESS_MASK,
                        shr(96, calldataload(pathOffset)) // tokenIn
                    ),
                    0,
                    ptr,
                    0x64,
                    ptr,
                    32
                )

                let rdsize := returndatasize()

                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            iszero(lt(rdsize, 32)), // at least 32 bytes
                            eq(mload(ptr), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }

            let indexData := calldataload(add(pathOffset, 22))
            let pool := and(shr(96, indexData), ADDRESS_MASK)
            let selectorId := and(shr(88, indexData), 0xff)
            let indexOut := and(shr(80, indexData), 0xff)
            let indexIn := and(shr(72, indexData), 0xff)

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////
            switch selectorId
            case 0 {
                indexData := true
                // selector for exchange(uint256,uint256,uint256,uint256)
                mstore(ptr, EXCHANGE)
                mstore(add(ptr, 0x4), indexIn)
                mstore(add(ptr, 0x24), indexOut)
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    let rdsize := returndatasize()
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
            case 1 {
                indexData := true
                // selector for exchange_underlying(uint256,uint256,uint256,uint256)
                mstore(ptr, EXCHANGE_UNDERLYING)
                mstore(add(ptr, 0x4), indexIn)
                mstore(add(ptr, 0x24), indexOut)
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    let rdsize := returndatasize()
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
            default {
                indexData := false
                // exchange_underlying(uint256,uint256,uint256,uint256,address)
                mstore(ptr, EXCHANGE_UNDERLYING_RECEIVER)
                mstore(add(ptr, 0x4), indexIn)
                mstore(add(ptr, 0x24), indexOut)
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    let rdsize := returndatasize()
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }

            amountOut := mload(ptr)

            ////////////////////////////////////////////////////
            // Send funds to receiver if needed
            ////////////////////////////////////////////////////
            if xor(indexData, xor(receiver, address())) {
                // selector for transfer(address,uint256)
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amountOut)
                let success := call(
                    gas(),
                    and(
                        ADDRESS_MASK,
                        shr(96, calldataload(add(pathOffset, 45))) // tokenIn, added 2x addr + 4x uint8
                    ),
                    0,
                    ptr,
                    0x44,
                    ptr,
                    32
                )

                let rdsize := returndatasize()

                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            iszero(lt(rdsize, 32)), // at least 32 bytes
                            eq(mload(ptr), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
        }
    }
}
