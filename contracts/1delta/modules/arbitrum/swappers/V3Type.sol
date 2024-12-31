// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {DeltaErrors} from "./Errors.sol";
import {ERC20Selectors} from "../../shared//selectors/ERC20Selectors.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @title Uniswap V3 type swapper contract
 * @notice Executes Cl swaps and pushing data to the callbacks
 */
abstract contract V3TypeSwapper is DeltaErrors, ERC20Selectors {
    ////////////////////////////////////////////////////
    // Masks
    ////////////////////////////////////////////////////

    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;
    /// @dev Mask of lower 1 byte.
    uint256 internal constant UINT8_MASK = 0xff;
    /// @dev Mask of lower 2 bytes 
    uint256 internal constant UINT16_MASK = 0xffff;
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal constant MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;
    /// @dev Maximum Uint256 value
    uint256 internal constant MAX_UINT256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    
    ////////////////////////////////////////////////////
    // param lengths
    ////////////////////////////////////////////////////

    uint256 internal constant MAX_SINGLE_LENGTH_UNOSWAP = 67;
    uint256 internal constant SKIP_LENGTH_UNOSWAP = 44; // = 20+1+1+20+2

    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    bytes32 internal constant SMARDEX_FF_FACTORY = 0xff9A1e1681f6D59Ca051776410465AfAda6384398f0000000000000000000000;
    bytes32 internal constant CODE_HASH_SMARDEX = 0x33bee911475f015247aeb1eebe149d1c6d2669be54126c29d85df6b0abb4c4e9;

    bytes32 internal constant UNI_V3_FF_FACTORY = 0xff1f98431c8ad98523631ae4a59f267346ea31f9840000000000000000000000;
    bytes32 internal constant UNI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant RETRO_FF_FACTORY = 0xff91e1B99072f238352f59e58de875691e20Dc19c10000000000000000000000;
    bytes32 internal constant RETRO_POOL_INIT_CODE_HASH = 0x817e07951f93017a93327ac8cc31e946540203a19e1ecc37bc1761965c2d1090;

    bytes32 internal constant IZI_FF_FACTORY = 0xffcA7e21764CD8f7c1Ec40e651E25Da68AeD0960370000000000000000000000;
    bytes32 internal constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    bytes32 internal constant ALGEBRA_V3_FF_DEPLOYER = 0xff2d98e2fa9da15aa6dc9581ab097ced7af697cb920000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_INIT_CODE_HASH = 0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4;

    bytes32 internal constant SUSHI_V3_FF_DEPLOYER = 0xff917933899c6a5F8E37F31E19f92CdBFF7e8FF0e20000000000000000000000;
    bytes32 internal constant SUSHI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

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
            // fromAmount = -fromAmount
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
