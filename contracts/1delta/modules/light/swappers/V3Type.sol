// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

import {Masks} from "../../shared/masks/Masks.sol";

/**
 * @title Uniswap V3 type swapper contract
 * @notice Executes Cl swaps and pushing data to the callbacks
 */
abstract contract V3TypeSwapper is Masks {
    ////////////////////////////////////////////////////
    // param lengths
    ////////////////////////////////////////////////////

    // offset for receiver address for most DEX types (uniswap, curve etc.)
    uint256 internal constant RECEIVER_OFFSET_UNOSWAP = 66;
    uint256 internal constant MAX_SINGLE_LENGTH_UNOSWAP = 67;
    /// @dev higher length limit for path length using lt()
    uint256 internal constant MAX_SINGLE_LENGTH_UNOSWAP_HIGH = 68;
    uint256 internal constant SKIP_LENGTH_UNOSWAP = 44; // = 20+1+1+20+2

    constructor() {}

    /// @dev Swap Uniswap V3 style exact in
    /// the calldata arrives as
    /// tokenIn | actionId | pool | fee | tokenOut
    /// @param pathLength we add a custom path length for flexible use
    function _swapUniswapV3PoolExactIn(
        uint256 fromAmount,
        uint256 minOut,
        address payer,
        address receiver,
        uint256 pathOffset,
        uint256 pathLength
    ) internal returns (uint256 receivedAmount) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            // read the pool address
            let pool := and(
                ADDRESS_MASK,
                calldataload(add(pathOffset, 10)) // starts as first param
            )
            // Return amount0 or amount1 depending on direction
            let zeroForOne := lt(
                shr(96, calldataload(pathOffset)), // tokenIn
                and(ADDRESS_MASK, calldataload(add(pathOffset, 32))) // tokenOut
            )

            // Prepare external call data
            // Store swap selector (0x128acb08)
            mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000)
            // Store toAddress
            mstore(add(ptr, 4), receiver)
            // Store direction
            mstore(add(ptr, 36), zeroForOne)
            // Store fromAmount
            mstore(add(ptr, 68), fromAmount)

            // Store data offset
            mstore(add(ptr, 132), 0xa0)
            // Store path
            calldatacopy(add(ptr, 196), pathOffset, pathLength)

            // within the callback, we add the maximum in amount
            mstore(add(add(ptr, 196), pathLength), shl(128, minOut))
            let _pathLength := add(pathLength, 16)
            // within the callback, we add the payer
            mstore(add(add(ptr, 196), _pathLength), shl(96, payer))
            _pathLength := add(_pathLength, 20)

            /// Store data length
            mstore(add(ptr, 164), _pathLength)

            switch zeroForOne
            case 0 {
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 100), MAX_SQRT_RATIO)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(228, _pathLength), ptr, 32)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }
                // If direction is 0, return amount0
                receivedAmount := mload(ptr)
            }
            default {
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 100), MIN_SQRT_RATIO)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(228, _pathLength), ptr, 64)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }

                // If direction is 1, return amount1
                receivedAmount := mload(add(ptr, 32))
            }
            // receivedAmount = -receivedAmount
            receivedAmount := sub(0, receivedAmount)
        }
    }

    /// @dev Swap exact input through izumi
    function _swapIZIPoolExactIn(
        uint256 fromAmount,
        uint256 minOut,
        address payer,
        address receiver,
        uint256 pathOffset,
        uint256 pathLength
    ) internal returns (uint256 receivedAmount) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            // read the pool address
            let pool := and(
                ADDRESS_MASK,
                calldataload(add(pathOffset, 10)) // starts as first param
            )
            // Return amount0 or amount1 depending on direction
            switch lt(
                shr(96, calldataload(pathOffset)), // tokenIn
                and(ADDRESS_MASK, calldataload(add(pathOffset, 32))) // tokenOut
            )
            case 0 {
                // Prepare external call data
                // Store swapY2X selector (0x2c481252)
                mstore(ptr, 0x2c48125200000000000000000000000000000000000000000000000000000000)
                // Store recipient
                mstore(add(ptr, 4), receiver)
                // Store fromAmount
                mstore(add(ptr, 36), fromAmount)
                // Store highPt
                mstore(add(ptr, 68), 799999)
                // Store data offset
                mstore(add(ptr, 100), 0x80)

                // Store path
                calldatacopy(add(ptr, 164), pathOffset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 164), pathLength), shl(128, minOut))
                let _pathLength := add(pathLength, 16)
                // within the callback, we add the payer
                mstore(add(add(ptr, 164), _pathLength), shl(96, payer))
                _pathLength := add(_pathLength, 20)

                /// Store data length
                mstore(add(ptr, 132), _pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(196, _pathLength), ptr, 32)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }
                // If direction is 0, return amount0
                receivedAmount := mload(ptr)
            }
            default {
                // Prepare external call data
                // Store swapX2Y selector (0x857f812f)
                mstore(ptr, 0x857f812f00000000000000000000000000000000000000000000000000000000)
                // Store toAddress
                mstore(add(ptr, 4), receiver)
                // Store fromAmount
                mstore(add(ptr, 36), fromAmount)
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 68), sub(0, 799999))
                // Store data offset
                mstore(add(ptr, 100), 0x80)

                // Store path
                calldatacopy(add(ptr, 164), pathOffset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 164), pathLength), shl(128, minOut))
                let _pathLength := add(pathLength, 16)
                // within the callback, we add the payer
                mstore(add(add(ptr, 164), _pathLength), shl(96, payer))
                _pathLength := add(_pathLength, 20)

                /// Store data length
                mstore(add(ptr, 132), _pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(196, _pathLength), ptr, 64)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }
                // If direction is 1, return amount1
                receivedAmount := mload(add(ptr, 32))
            }
        }
    }

    /// @dev Swap exact output through izumi
    function _swapIZIPoolExactOut(
        uint256 toAmount,
        uint256 maxIn,
        address payer,
        address receiver,
        uint256 pathOffset,
        uint256 pathLength
    ) internal returns (uint256 fromAmount) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            let pool := and(
                ADDRESS_MASK,
                calldataload(add(pathOffset, 10)) // starts as first param
            )
            // Return amount0 or amount1 depending on direction
            switch lt(
                and(ADDRESS_MASK, calldataload(add(pathOffset, 32))), // tokenIn
                shr(96, calldataload(pathOffset)) // tokenOut
            )
            case 0 {
                // Prepare external call data
                // Store swapY2XDesireX selector (0xf094685a)
                mstore(ptr, 0xf094685a00000000000000000000000000000000000000000000000000000000)
                // Store recipient
                mstore(add(ptr, 4), receiver)
                // Store toAmount
                mstore(add(ptr, 36), toAmount)
                // Store highPt
                mstore(add(ptr, 68), 800001)
                // Store data offset
                mstore(add(ptr, 100), 0x80)
                /// Store data length
                mstore(add(ptr, 132), pathLength)
                // Store path
                calldatacopy(add(ptr, 164), pathOffset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 164), pathLength), shl(128, maxIn))
                let _pathLength := add(pathLength, 16)
                // and the payer address
                mstore(add(add(ptr, 164), _pathLength), shl(96, payer))
                _pathLength := add(_pathLength, 20)

                /// Store data length
                mstore(add(ptr, 132), _pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(196, _pathLength), ptr, 64)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }
                // If direction is 1, return amount1
                fromAmount := mload(add(ptr, 32))
            }
            default {
                // Prepare external call data
                // Store swapX2YDesireY selector (0x59dd1436)
                mstore(ptr, 0x59dd143600000000000000000000000000000000000000000000000000000000)
                // Store toAddress
                mstore(add(ptr, 4), receiver)
                // Store toAmount
                mstore(add(ptr, 36), toAmount)
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 68), sub(0, 800001))
                // Store data offset
                mstore(add(ptr, 100), 0x80)
                // Store path
                calldatacopy(add(ptr, 164), pathOffset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 164), pathLength), shl(128, maxIn))
                let _pathLength := add(pathLength, 16)
                // and the payer address
                mstore(add(add(ptr, 164), _pathLength), shl(96, payer))
                _pathLength := add(_pathLength, 20)

                /// Store data length
                mstore(add(ptr, 132), _pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(196, _pathLength), ptr, 32)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }
                // If direction is 0, return amount0
                fromAmount := mload(ptr)
            }
        }
    }

    /// @dev swap uniswap V3 style exact out
    function _swapUniswapV3PoolExactOut(
        uint256 fromAmount,
        uint256 maxIn,
        address payer,
        address receiver,
        uint256 pathOffset,
        uint256 pathLength
    ) internal returns (uint256 receivedAmount) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            let pool := and(
                ADDRESS_MASK,
                calldataload(add(pathOffset, 10)) // starts as first param
            )
            // Return amount0 or amount1 depending on direction
            let zeroForOne := lt(
                and(ADDRESS_MASK, calldataload(add(pathOffset, 32))), // tokenIn
                shr(96, calldataload(pathOffset)) // tokenOut
            )

            // Return amount0 or amount1 depending on direction
            // Prepare external call data
            // Store swap selector (0x128acb08)
            mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000)
            // Store toAddress
            mstore(add(ptr, 4), receiver)
            // Store direction
            mstore(add(ptr, 36), zeroForOne)
            // Store -fromAmount
            mstore(add(ptr, 68), sub(0, fromAmount))
            // Store data offset
            mstore(add(ptr, 132), 0xa0)
            // Store path
            calldatacopy(add(ptr, 196), pathOffset, pathLength)

            // within the callback, we add the maximum in amount
            mstore(add(add(ptr, 196), pathLength), shl(128, maxIn))
            let _pathLength := add(pathLength, 16)
            // and the payer address
            mstore(add(add(ptr, 196), _pathLength), shl(96, payer))
            _pathLength := add(_pathLength, 20)

            /// Store data length
            mstore(add(ptr, 164), _pathLength)

            switch zeroForOne
            case 0 {
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 100), MAX_SQRT_RATIO)
                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(228, _pathLength), ptr, 32)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }
                // If direction is 1, return amount1
                receivedAmount := mload(add(ptr, 32))
            }
            default {
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 100), MIN_SQRT_RATIO)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(228, _pathLength), ptr, 64)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }

                // If direction is 0, return amount0
                receivedAmount := mload(ptr)
            }
        }
    }
}
