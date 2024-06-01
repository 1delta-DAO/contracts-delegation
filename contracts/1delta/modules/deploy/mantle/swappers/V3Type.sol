// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;


/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @title Base swapper contract
 * @notice Contains basic logic for swap executions with DEXs
 */
abstract contract V3TypeSwapper {
    // this is the slot for the cache
    bytes32 internal constant CACHE_SLOT = 0x468881cf549dc8cc10a98ff7dab63b93cde29208fb93e08f19acee97cac5ba05;
    bytes32 internal constant NUMBER_CACHE_SLOT = 0xcff5bbd1b2d2801305f53eb2f94cba4428e797852af2f6b82f41fdca2c9a278a;

    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;   
    /// @dev Mask of lower 1 byte.
    uint256 internal constant UINT8_MASK = 0xff;
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal constant MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

    bytes32 internal constant FUSION_V3_FF_FACTORY = 0xff8790c2C3BA67223D83C8FCF2a5E3C650059987b40000000000000000000000;
    bytes32 internal constant FUSION_POOL_INIT_CODE_HASH = 0x1bce652aaa6528355d7a339037433a20cd28410e3967635ba8d2ddb037440dbf;

    bytes32 internal constant AGNI_V3_FF_FACTORY = 0xffe9827B4EBeB9AE41FC57efDdDd79EDddC2EA4d030000000000000000000000;
    bytes32 internal constant AGNI_POOL_INIT_CODE_HASH = 0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a;

    bytes32 internal constant IZI_FF_FACTORY = 0xff45e5F26451CDB01B0fA1f8582E0aAD9A6F27C2180000000000000000000000;
    bytes32 internal constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    bytes32 internal constant ALGEBRA_V3_FF_DEPLOYER = 0xff9dE2dEA5c68898eb4cb2DeaFf357DFB26255a4aa0000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_INIT_CODE_HASH = 0x177d5fbf994f4d130c008797563306f1a168dc689f81b2fa23b4396931014d91;

    bytes32 internal constant BUTTER_FF_FACTORY = 0xffeeca0a86431a7b42ca2ee5f479832c3d4a4c26440000000000000000000000;
    bytes32 internal constant BUTTER_POOL_INIT_CODE_HASH = 0xc7d06444331e4f63b0764bb53c88788882395aa31961eed3c2768cc9568323ee;

    bytes32 internal constant CLEO_FF_FACTORY = 0xffAAA32926fcE6bE95ea2c51cB4Fcb60836D320C420000000000000000000000;
    bytes32 internal constant CLEO_POOL_INIT_CODE_HASH = 0x1565b129f2d1790f12d45301b9b084335626f0c92410bc43130763b69971135d;

    bytes32 internal constant METHLAB_FF_FACTORY = 0xff8f140fc3e9211b8dc2fc1d7ee3292f6817c5dd5d0000000000000000000000;
    bytes32 internal constant METHLAB_INIT_CODE_HASH = 0xacd26fbb15704ae5e5fe7342ea8ebace020e4fa5ad4a03122ce1678278cf382b;

    constructor() {}

    uint256 internal constant UNI3_CALLDATA_LENGTH = 44; // uint8, uint8, uint16, sandwiched by 2 addresses
    uint256 internal constant UNI3_TOKEN_OUT_OFFSET = 44;
    uint256 internal constant UNI3_POOL_OFFSET = 22;
    uint256 internal constant UINT16_MASK = 0xffff;

    /// @dev Swap Uniswap V3 style exact in
    /// the calldata arrives as
    /// tokenIn | actionId | fee | tokenOut
    function _swapUniswapV3PoolExactIn(
        uint256 fromAmount,
        uint256 minOut,
        address payer,
        address receiver,
        bytes calldata path
    )
        internal
        returns (uint256 receivedAmount)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            let firstWord := calldataload(path.offset)
            let _pId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // get tokens
            let tokenA := and(ADDRESS_MASK, shr(96, firstWord))
            firstWord := calldataload(add(path.offset, 42))
            let tokenB := and(ADDRESS_MASK, shr(80, firstWord))
            
            // read the pool address
            let pool := and(
                ADDRESS_MASK,
                shr(
                    96,
                    calldataload(add(path.offset, 22))
                )
            )
            let pathLength := path.length
            // Return amount0 or amount1 depending on direction
            switch lt(tokenA, tokenB)
            case 0 {
                // Prepare external call data
                // Store swap selector (0x128acb08)
                mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000)
                // Store toAddress
                mstore(add(ptr, 4), receiver)
                // Store direction
                mstore(add(ptr, 36), 0)
                // Store fromAmount
                mstore(add(ptr, 68), fromAmount)
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 100), MAX_SQRT_RATIO)
                // Store data offset
                mstore(add(ptr, 132), 0xa0)
                // Store path
                calldatacopy(add(ptr, 196), path.offset, pathLength)
                
                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 196), pathLength), shl(128, minOut))
                pathLength := add(pathLength, 16)
                // within the callback, we add the payer
                mstore(add(add(ptr, 196), pathLength), shl(96, payer))
                pathLength := add(pathLength, 20)
                
                /// Store data length
                mstore(add(ptr, 164), pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(228, pathLength), ptr, 32)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }
                // If direction is 0, return amount0
                fromAmount := mload(ptr)
            }
            default {
                // Prepare external call data
                // Store swap selector (0x128acb08)
                mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000)
                // Store toAddress
                mstore(add(ptr, 4), receiver)
                // Store direction
                mstore(add(ptr, 36), 1)
                // Store fromAmount
                mstore(add(ptr, 68), fromAmount)
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 100), MIN_SQRT_RATIO)
                // Store data offset
                mstore(add(ptr, 132), 0xa0)
                // Store path
                calldatacopy(add(ptr, 196), path.offset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 196), pathLength), shl(128, minOut))
                pathLength := add(pathLength, 16)
                // within the callback, we add the payer
                mstore(add(add(ptr, 196), pathLength), shl(96, payer))
                pathLength := add(pathLength, 20)

                /// Store data length
                mstore(add(ptr, 164), pathLength)
                
                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(228, pathLength), ptr, 64)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }

                // If direction is 1, return amount1
                fromAmount := mload(add(ptr, 32))
            }
            // fromAmount = -fromAmount
            receivedAmount := sub(0, fromAmount)
        }
    }

    /// @dev Swap exact input through izumi
    function _swapIZIPoolExactIn(
        uint128 fromAmount,
        uint256 minOut,
        address payer,
        address receiver,
        bytes calldata path
    )
        internal
        returns (uint256 receivedAmount)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            let firstWord := calldataload(path.offset)
            let _pId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // get tokens
            let tokenA := and(ADDRESS_MASK, shr(96, firstWord))
            firstWord := calldataload(add(path.offset, 42))
            let tokenB := and(ADDRESS_MASK, shr(80, firstWord))
            
            // read the pool address
            let pool := and(
                ADDRESS_MASK,
                shr(
                    96,
                    calldataload(add(path.offset, 22))
                )
            )
            let pathLength := path.length
            // Return amount0 or amount1 depending on direction
            switch lt(tokenA, tokenB)
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
                mstore(add(ptr, 100), sub(0xa0, 0x20))

                // Store path
                calldatacopy(add(ptr, 164), path.offset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 164), pathLength), shl(128, minOut))
                pathLength := add(pathLength, 16)
                // within the callback, we add the payer
                mstore(add(add(ptr, 164), pathLength), shl(96, payer))
                pathLength := add(pathLength, 20)
                
                /// Store data length
                mstore(add(ptr, 132), pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(196, pathLength), ptr, 32)) {
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
                mstore(add(ptr, 100), sub(0xa0, 0x20))

                // Store path
                calldatacopy(add(ptr, 164), path.offset, pathLength)
                
                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 164), pathLength), shl(128, minOut))
                pathLength := add(pathLength, 16)
                // within the callback, we add the payer
                mstore(add(add(ptr, 164), pathLength), shl(96, payer))
                pathLength := add(pathLength, 20)
                
                /// Store data length
                mstore(add(ptr, 132), pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(196, pathLength), ptr, 64)) {
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
        uint128 toAmount,
        uint256 maxIn,
        address payer,
        address receiver,
        bytes calldata path
    )
        internal
        returns (uint256 fromAmount)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            let firstWord := calldataload(path.offset)
            let tokenB := and(ADDRESS_MASK, shr(96, firstWord))
            firstWord := calldataload(add(path.offset, 42))
            let tokenA := and(ADDRESS_MASK, shr(80, firstWord))
            // read the pool address
            let pool := and(
                ADDRESS_MASK,
                shr(
                    96,
                    calldataload(add(path.offset, 22))
                )
            )
            let pathLength := path.length
            // Return amount0 or amount1 depending on direction
            switch lt(tokenA, tokenB)
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
                mstore(add(ptr, 100), sub(0xa0, 0x20))
                /// Store data length
                mstore(add(ptr, 132), path.length)
                // Store path
                calldatacopy(add(ptr, 164), path.offset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 164), pathLength), shl(128, maxIn))
                pathLength := add(pathLength, 16)
                // and the payer address
                mstore(add(add(ptr, 164), pathLength), shl(96, payer))
                pathLength := add(pathLength, 20)
                
                /// Store data length
                mstore(add(ptr, 132), pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(196, pathLength), ptr, 64)) {
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
                mstore(add(ptr, 100), sub(0xa0, 0x20))
                // Store path
                calldatacopy(add(ptr, 164), path.offset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 164), pathLength), shl(128, maxIn))
                pathLength := add(pathLength, 16)
                // and the payer address
                mstore(add(add(ptr, 164), pathLength), shl(96, payer))
                pathLength := add(pathLength, 20)
                
                /// Store data length
                mstore(add(ptr, 132), pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(196, pathLength), ptr, 32)) {
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
        int256 fromAmount,
        uint256 maxIn,
        address payer,
        address receiver,
        bytes calldata path
    )
        internal
        returns (uint256 receivedAmount)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            let firstWord := calldataload(path.offset)
            let poolId := and(shr(80, firstWord), UINT8_MASK) // poolId
            let tokenB := and(ADDRESS_MASK, shr(96, firstWord))
            firstWord := calldataload(add(path.offset, 42))
            let tokenA := and(ADDRESS_MASK, shr(80, firstWord))
            // read the pool address
            let pool := and(
                ADDRESS_MASK,
                shr(
                    96,
                    calldataload(add(path.offset, 22))
                )
            )

            let pathLength := path.length
            // Return amount0 or amount1 depending on direction
            switch lt(tokenA, tokenB)
            case 0 {
                // Prepare external call data
                // Store swap selector (0x128acb08)
                mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000)
                // Store toAddress
                mstore(add(ptr, 4), receiver)
                // Store direction
                mstore(add(ptr, 36), 0)
                // Store fromAmount
                mstore(add(ptr, 68), fromAmount)
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 100), MAX_SQRT_RATIO)
                // Store data offset
                mstore(add(ptr, 132), 0xa0)
                // Store path
                calldatacopy(add(ptr, 196), path.offset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 196), pathLength), shl(128, maxIn))
                pathLength := add(pathLength, 16)
                // and the payer address
                mstore(add(add(ptr, 196), pathLength), shl(96, payer))
                pathLength := add(pathLength, 20)
                
                /// Store data length
                mstore(add(ptr, 164), pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(228, pathLength), ptr, 32)) {
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
                // Store swap selector (0x128acb08)
                mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000)
                // Store toAddress
                mstore(add(ptr, 4), receiver)
                // Store direction
                mstore(add(ptr, 36), 1)
                // Store fromAmount
                mstore(add(ptr, 68), fromAmount)
                // Store sqrtPriceLimitX96
                mstore(add(ptr, 100), MIN_SQRT_RATIO)
                // Store data offset
                mstore(add(ptr, 132), 0xa0)
                // Store path
                calldatacopy(add(ptr, 196), path.offset, pathLength)

                // within the callback, we add the maximum in amount
                mstore(add(add(ptr, 196), pathLength), shl(128, maxIn))
                pathLength := add(pathLength, 16)
                // then we add the payer
                mstore(add(add(ptr, 196), pathLength), shl(96, payer))
                pathLength := add(pathLength, 20)
                
                /// Store data length
                mstore(add(ptr, 164), pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pool, 0, ptr, add(228, pathLength), ptr, 64)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }

                // If direction is 0, return amount0
                fromAmount := mload(ptr)
            }
            // fromAmount = -fromAmount
            receivedAmount := fromAmount
        }
    }
}
