// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

import { ERC20Selectors } from "../selectors/ERC20Selectors.sol";
import { Masks } from "../masks/Masks.sol";

/**
 * @title Curve swapper contract
 * @notice We do Curve stuff here
 */
abstract contract CurveSwapper is ERC20Selectors, Masks {
    // approval slot
    bytes32 private constant CALL_MANAGEMENT_APPROVALS = 0x1aae13105d9b6581c36534caba5708726e5ea1e03175e823c989a5756966d1f3;

    /** Standard curve pool selectors */

    ////////////////////////////////////////////////////
    // General info on the selectors for Curve:
    // There are 5 variations
    // 1) indexes as int128
    // 2) indexes as uint256
    // 3) has receiver
    // 4) has no receiver
    // 5) fork with solidity implementation (typically uint8 indexes)
    // The int128 indexes are preferred and have lower indexes
    // The ones with receiver have even indexes
    ////////////////////////////////////////////////////

    /// @notice selector exchange(int128,int128,uint256,uint256)
    bytes32 private constant EXCHANGE_INT = 0x3df0212400000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange(int128,int128,uint256,uint256,address)
    bytes32 private constant EXCHANGE_INT_WITH_RECEIVER = 0xddc1f59d00000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE = 0x5b41b90800000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange(uint256,uint256,uint256,uint256,address)
    bytes32 private constant EXCHANGE_WITH_RECEIVER = 0xa64833a000000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_underlying(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE_UNDERLYING = 0x65b2489b00000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_underlying(uint256,uint256,uint256,uint256,address)
    bytes32 private constant EXCHANGE_UNDERLYING_WITH_RECEIVER = 0xe2ad025a00000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_underlying(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE_UNDERLYING_INT = 0xa6417ed600000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_underlying(uint256,uint256,uint256,uint256,address)
    bytes32 private constant EXCHANGE_UNDERLYING_INT_WITH_RECEIVER = 0x44ee198600000000000000000000000000000000000000000000000000000000;

    ////////////////////////////////////////////////////
    // General info on the selectors for Curve Received:
    // They are pre-funded
    // 1) indexes as int128 (NG) or uint256 (Some of the TriCryptos) as above
    // 2) has always a receiver (optinally could be called without it, bet there is no utility for it)
    ////////////////////////////////////////////////////

    /// @notice selector exchange_received(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE_RECEIVED = 0x29b244bb00000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_received(uint256,uint256,uint256,uint256,address)
    bytes32 private constant EXCHANGE_RECEIVED_WITH_RECEIVER = 0x767691e700000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange(int128,int128,uint256,uint256)
    bytes32 private constant EXCHANGE_RECEIVED_INT = 0x7e3db03000000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_received(int128,int128,uint256,uint256,address)
    bytes32 private constant EXCHANGE_RECEIVED_INT_WITH_RECEIVER = 0xafb4301200000000000000000000000000000000000000000000000000000000;

    /// @notice selector for cuve forks using solidity swap(uint8,uint8,uint256,uint256,uint256)
    bytes32 private constant SWAP = 0x9169558600000000000000000000000000000000000000000000000000000000;

    /// @notice Curve params lengths
    uint256 internal constant SKIP_LENGTH_CURVE = 45; // = 20+1+1+20+1+1+1
    uint256 internal constant RECEIVER_OFFSET_CURVE = 67; // = SKIP_LENGTH_CURVE+20+2
    uint256 internal constant MAX_SINGLE_LENGTH_CURVE = 68; // = SKIP_LENGTH_CURVE+20+1+2
    uint256 internal constant MAX_SINGLE_LENGTH_CURVE_HIGH = 69; // = SKIP_LENGTH_CURVE+20+1+2+1

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
            let tokenIn := shr(96, calldataload(pathOffset))
            ////////////////////////////////////////////////////
            // Pull funds if needed
            ////////////////////////////////////////////////////
            if xor(payer, address()) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(gas(), tokenIn, 0, ptr, 0x64, ptr, 32)

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
            let pool := shr(96, indexData) // pool is first param

            ////////////////////////////////////////////////////
            // Approve pool if needed
            ////////////////////////////////////////////////////
            mstore(0x0, tokenIn)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, pool)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // approveFlag
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), pool)
                mstore(add(ptr, 0x24), MAX_UINT256)
                pop(
                    call(
                        gas(),
                        tokenIn, //
                        0,
                        ptr,
                        0x44,
                        ptr,
                        32
                    )
                )
                sstore(key, 1)
            }

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////
            switch and(shr(72, indexData), 0xff) // selectorId
            case 0 {
                // selector for exchange(int128,int128,uint256,uint256,address)
                mstore(ptr, EXCHANGE_INT_WITH_RECEIVER)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
                mstore(add(ptr, 0x84), receiver) // receiver, set indexData accordingly
                if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0
            }
            case 1 {
                // selector for exchange(int128,int128,uint256,uint256)
                mstore(ptr, EXCHANGE_INT)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            case 2 {
                // selector for exchange(uint256,uint256,uint256,uint256,address)
                mstore(ptr, EXCHANGE_WITH_RECEIVER)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the
                mstore(add(ptr, 0x84), receiver) // receiver, set indexData accordingly
                if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0
            }
            case 3 {
                // selector for exchange(uint256,uint256,uint256,uint256)
                mstore(ptr, EXCHANGE)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            case 4 {
                // selector for exchange_underlying(int128,int128,uint256,uint256,address)
                mstore(ptr, EXCHANGE_UNDERLYING_INT_WITH_RECEIVER)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
                mstore(add(ptr, 0x84), receiver)
                if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0
            }
            case 5 {
                // selector for exchange_underlying(int128,int128,uint256,uint256)
                mstore(ptr, EXCHANGE_UNDERLYING_INT)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            case 6 {
                // selector for exchange_underlying(uint256,uint256,uint256,uint256,address)
                mstore(ptr, EXCHANGE_UNDERLYING_WITH_RECEIVER)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
                mstore(add(ptr, 0x84), receiver)
                if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0
            }
            case 7 {
                // selector for exchange_underlying(uint256,uint256,uint256,uint256)
                mstore(ptr, EXCHANGE_UNDERLYING)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            case 200 {
                // selector for swap(uint8,uint8,uint256,uint256,uint256)
                mstore(ptr, SWAP)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
                mstore(add(ptr, 0x84), MAX_UINT256) // deadline
                if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            default {
                revert(0, 0)
            }

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
                    shr(96, calldataload(add(pathOffset, 45))), // tokenIn, pool + 5x uint8 (i,j,s,a)
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
                            gt(rdsize, 31), // at least 32 bytes
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
    function _swapCurveReceived(
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
                // selector for exchange_received(int128,int128,uint256,uint256,address)
                mstore(ptr, EXCHANGE_RECEIVED_INT_WITH_RECEIVER)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff)) // indexIn
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff)) // indexOut
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
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
            }
            case 2 {
                // selector for exchange_received(uint256,uint256,uint256,uint256,address)
                mstore(ptr, EXCHANGE_RECEIVED_WITH_RECEIVER)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff)) // indexIn
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff)) // indexOut
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out
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
            }
            default {
                revert(0, 0)
            }

            amountOut := mload(ptr)
        }
    }

    /**
     * Swaps using a NG pool exact out
     * The indexes are provided (due to the use in the calculator)
     */
    function _swapCurveReceivedExactOut(
        address pool,
        uint256 pathOffset,
        uint256 indexIn,
        uint256 indexOut,
        uint256 computedAmountIn,
        address receiver //
    ) internal {
        assembly {
            let ptr := mload(0x40)

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////
            switch and(shr(72, calldataload(add(pathOffset, 22))), 0xff)
            case 0 {
                // selector for exchange_received(int128,int128,uint256,uint256,address)
                mstore(ptr, EXCHANGE_RECEIVED_INT_WITH_RECEIVER)
                mstore(add(ptr, 0x4), indexIn) // indexIn
                mstore(add(ptr, 0x24), indexOut) // indexOut
                mstore(add(ptr, 0x44), computedAmountIn)
                mstore(add(ptr, 0x64), 0) // min out
                mstore(add(ptr, 0x84), receiver)
                if iszero(
                    call(
                        gas(),
                        pool,
                        0x0,
                        ptr,
                        0xA4, //
                        ptr,
                        0x20
                    )
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            case 2 {
                // selector for exchange_received(uint256,uint256,uint256,uint256,address)
                mstore(ptr, EXCHANGE_RECEIVED_WITH_RECEIVER)
                mstore(add(ptr, 0x4), indexIn) // indexIn
                mstore(add(ptr, 0x24), indexOut) // indexOut
                mstore(add(ptr, 0x44), computedAmountIn)
                mstore(add(ptr, 0x64), 0) // min out
                mstore(add(ptr, 0x84), receiver)
                if iszero(
                    call(
                        gas(),
                        pool,
                        0x0,
                        ptr,
                        0xA4, //
                        ptr,
                        0x20
                    )
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            default {
                revert(0, 0)
            }
        }
    }

    /**
     * Gets the input amount for a curve NG swap
     * Note that this has an adjustment of 0.5 bps for the output amount to account for inaccuracies
     * when swapping using `exchange` or `exchange_received`
     */
    function _getNGAmountIn(address pool, uint256 indexIn, uint256 indexOut, uint256 amountOut) internal view returns (uint256 amountIn) {
        assembly {
            let ptr := mload(0x40)

            // selector for get_dx(int128,int128,uint256)
            mstore(ptr, 0x67df02ca00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), indexIn)
            mstore(add(ptr, 0x24), indexOut)
            mstore(
                add(ptr, 0x44),
                div(
                    // we upscale to avoid insufficient amount received
                    // tah is, becaus the feature is not accurate
                    mul(
                        10000050, // 0.05bp = 10_000_0_50
                        amountOut
                    ),
                    10000000
                )
            )
            // ignore whether it succeeds as we expect the swap to fail in that case
            pop(staticcall(gas(), pool, ptr, 0x64, 0x0, 0x20))

            amountIn := mload(0x0)
        }
    }
}
