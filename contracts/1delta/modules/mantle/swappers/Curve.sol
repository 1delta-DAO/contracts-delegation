// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {UniTypeSwapper} from "./UniType.sol";

/**
 * @title Curve swapper contract
 * @notice We do Curve stuff here
 */
abstract contract CurveSwapper is UniTypeSwapper {
    // slot to track approvals
    bytes32 internal constant APPROVAL_SLOT = 0xf92cf179e3ab8e843f6d42d0191a950808c083864fd707bf1142aab5c60b560b;

    /** Standard curve pool selectors */

    /// @notice selector exchange(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE = 0x5b41b90800000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange(int128,int128,uint256,uint256)
    bytes32 private constant EXCHANGE_INT = 0x3df0212400000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_underlying(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE_UNDERLYING = 0xa6417ed600000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_underlying(uint256,uint256,uint256,uint256,address)
    bytes32 private constant EXCHANGE_UNDERLYING_RECEIVER = 0xe2ad025a00000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_received(int128,int128,uint256,uint256,address)
    bytes32 private constant EXCHANGE_RECEIVED = 0xafb4301200000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange(int128,int128,uint256,uint256,address)
    bytes32 private constant EXCHANGE_RECEIVED_INT = 0xddc1f59d00000000000000000000000000000000000000000000000000000000;

    /// @notice selector for cuve forks usibng solidity swap(uint8,uint8,uint256,uint256,uint256)
    bytes32 private constant SWAP = 0x9169558600000000000000000000000000000000000000000000000000000000;

    /// @notice Curve params lengths
    uint256 internal constant SKIP_LENGTH_CURVE = 45; // = 20+1+1+20+1+1+1
    uint256 internal constant RECEIVER_OFFSET_CURVE = 67; // = SKIP_LENGTH_CURVE+20+2
    uint256 internal constant MAX_SINGLE_LENGTH_CURVE = 68; // = SKIP_LENGTH_CURVE+20+1+2
    uint256 internal constant MAX_SINGLE_LENGTH_CURVE_HIGH = 69; // = SKIP_LENGTH_CURVE+20+1+2+1

    constructor() {}

    /**
     * Swaps using a standard curve pool
     * Data is supposed to be packed as follows
     * tokenIn | actionId | dexId | pool | i | j | sm | tokenOut
     * sm is the selector,
     * i,j are the swap indexes for the pool
     */
    function _swapCurveGeneral(
        uint256 pathOffset,
        uint256 amountIn,
        address payer,
        address receiver //
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            let token := shr(96, calldataload(pathOffset))
            ////////////////////////////////////////////////////
            // Pull funds if needed
            ////////////////////////////////////////////////////
            if xor(payer, address()) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(
                    gas(),
                    token, //
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

            // this one contains [pool | i | j | s | ...]
            let indexData := calldataload(add(pathOffset, 22))
            let pool := shr(96, indexData) // pool is first param

            ////////////////////////////////////////////////////
            // Approve pool if needed
            ////////////////////////////////////////////////////

            // get the approval flag slot first
            mstore(0x0, token) // store tokenIn in scrap
            mstore(0x20, APPROVAL_SLOT) // add slot after
            let slot := keccak256(0x0, 0x40)

            // check if approval flag is zero
            if iszero(sload(slot)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), pool)
                mstore(add(ptr, 0x24), MAX_UINT256)
                pop(
                    call(
                        gas(),
                        token, // tokenIn
                        0,
                        ptr,
                        0x44,
                        ptr,
                        32
                    )
                )
                sstore(slot, 1) // set flag in approval slot
            }

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////
            switch and(shr(72, indexData), 0xff) // selectorId
            case 0 {
                // selector for exchange(int128,int128,uint256,uint256)
                mstore(ptr, EXCHANGE_INT)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            case 1 {
                // exchange(int128,int128,uint256,uint256,address)
                mstore(ptr, EXCHANGE_RECEIVED_INT)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                mstore(add(ptr, 0x84), receiver)
                if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0
            }
            case 2 {
                // selector for exchange(uint256,uint256,uint256,uint256)
                mstore(ptr, EXCHANGE)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            case 3 {
                // selector for exchange_underlying(uint256,uint256,uint256,uint256)
                mstore(ptr, EXCHANGE_UNDERLYING)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            case 4 {
                // exchange_underlying(uint256,uint256,uint256,uint256,address)
                mstore(ptr, EXCHANGE_UNDERLYING_RECEIVER)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                mstore(add(ptr, 0x84), receiver)
                if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0
            }
            case 5 {
                // selector for swap(uint8,uint8,uint256,uint256,uint256)
                mstore(ptr, SWAP)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                mstore(add(ptr, 0x84), MAX_UINT256)
                if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            default {
                revert(0, 0)
            }

            // we need to get the output amount as these cuve forks
            // might not return amountOut - assign tokenOut to `token`
            token := shr(96, calldataload(add(pathOffset, 45))) // tokenIn, pool + 5x uint8 (i,j,s)
            // load the retrieved balance
            amountOut := mload(ptr)

            ////////////////////////////////////////////////////
            // Send funds to receiver if needed
            // indexData is now the flag for manually
            // transferuing to the receiver
            ////////////////////////////////////////////////////
            if and(indexData, xor(receiver, address())) {
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amountOut)
                let success := call(
                    gas(),
                    token, // tokenIn, pool + 5x uint8 (i,j,s)
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

    /**
     * Swaps using a NG pool that allows for pre-funded swaps
     * Data is supposed to be packed as follows
     * tokenIn | actionId | dexId | pool | sm | i | j | tokenOut
     * sm is the selector,
     * i,j are the swap indexes for the pool
     */
    function _swapCurveNG(
        uint256 pathOffset,
        uint256 amountIn,
        address receiver //
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            let indexData := calldataload(add(pathOffset, 22))

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////
            switch and(shr(72, indexData), 0xff)
            case 0 {
                // selector for exchange_received(uint256,uint256,uint256,uint256,address)
                mstore(ptr, EXCHANGE_RECEIVED)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff)) // indexIn
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff)) // indexOut
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                mstore(add(ptr, 0x84), receiver)
                if iszero(
                    call(
                        gas(),
                        shr(96, indexData), // pool
                        0x0,
                        ptr,
                        0xA4,
                        ptr,
                        0x20
                    )
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            default {
                revert(0, 0)
            }

            amountOut := mload(ptr)
        }
    }
}
