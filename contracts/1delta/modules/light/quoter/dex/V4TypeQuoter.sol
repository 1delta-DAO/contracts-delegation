// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DexTypeMappings} from "../../swappers/dex/DexTypeMappings.sol";

interface IUniswapV4Poolmanager {
    function unlock(bytes calldata data) external returns (bytes memory);
}

abstract contract V4TypeQuoter is Masks {
    /// @dev Transient storage variable used to check a safety condition in exact output swaps
    uint256 private amountOutCached;
    /** We need all these selectors for executing a single swap */
    bytes32 private constant SWAP = 0xf3cd914c00000000000000000000000000000000000000000000000000000000;
    bytes32 private constant TAKE = 0x0b0d9c0900000000000000000000000000000000000000000000000000000000;
    bytes32 private constant SETTLE = 0x11da60b400000000000000000000000000000000000000000000000000000000;
    bytes32 private constant SYNC = 0xa584119400000000000000000000000000000000000000000000000000000000;
    bytes32 private constant EXTTLOAD = 0x9bf6645f00000000000000000000000000000000000000000000000000000000;

    constructor() {}

    /**
     * Callback from uniswap V4 type singletons
     * As Balancer V3 shares the same trigger selector and (unlike this one) has
     * a custom selector provided, we need to skip this part of the data
     * This is mainly done to not have duplicate code and maintain
     * the same level of security by callback validation for both DEX types
     */
    function unlockCallback(bytes calldata data) external {
        uint256 currentOffset;
        uint256 amountIn;
        address tokenIn;
        address tokenOut;
        assembly {
            currentOffset := data.offset
            amountIn := shr(128, calldataload(currentOffset))
            tokenIn := shr(96, calldataload(add(currentOffset, 16)))
            tokenOut := shr(96, calldataload(add(currentOffset, 36)))
            currentOffset := add(currentOffset, 56)
        }

        _simSwapUniswapV4ExactInGeneric(
            amountIn,
            tokenIn, //
            tokenOut,
            currentOffset
        );
    }

    /*
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | hooks                |
     * | 20     | 20             | manager              |
     * | 40     | 3              | fee                  |
     * | 43     | 3              | tickSpacing          |
     * | 46     | 1              | payFlag              |
     * | 47     | 2              | calldataLength       |
     * | 49     | calldataLength | calldata             |
     */
    function _getV4TypeAmountOut(
        uint256 fromAmount,
        address tokenIn,
        address tokenOut,
        uint256 currentOffset
    )
        internal
        returns (
            uint256 receivedAmount,
            // similar to other implementations, we use this temp variable
            // to avoid stackToo deep
            uint256 tempVar
        )
    {
        address manager;
        uint256 clLength;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // read the manager address
            let data := calldataload(add(currentOffset, 20))
            clLength := and(UINT16_MASK, shr(8, data))
            manager := shr(96, data)
        }
        bytes calldata calldataForCallback;
        assembly {
            calldataForCallback.offset := currentOffset
            calldataForCallback.length := add(49, clLength)
        }

        try
            IUniswapV4Poolmanager(manager).unlock(
                abi.encodePacked(
                    // add quoite-relevant data
                    uint128(fromAmount),
                    tokenIn, //
                    tokenOut,
                    calldataForCallback
                )
            )
        {} catch (bytes memory reason) {
            return (parseRevertReason(reason), currentOffset);
        }
        revert("Did not revert in V4 CB");
    }

    /*
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | hooks                |
     * | 20     | 20             | manager              |
     * | 40     | 3              | fee                  |
     * | 43     | 3              | tickSpacing          |
     * | 46     | 1              | payFlag              |
     * | 47     | 2              | calldataLength       |
     * | 49     | calldataLength | calldata             |
     */
    function _simSwapUniswapV4ExactInGeneric(
        uint256 fromAmount,
        address tokenIn,
        address tokenOut, //
        uint256 currentOffset
    ) internal {
        uint256 tempVar;
        // struct PoolKey {
        //     address currency0; 4
        //     address currency1; 36
        //     uint24 fee; 68
        //     int24 tickSpacing; 100
        //     address hooks; 132
        // }
        // struct SwapParams {
        //     bool zeroForOne; 164
        //     int256 amountSpecified; 196
        //     uint160 sqrtPriceLimitX96; 228
        // }
        ////////////////////////////////////////////
        // This is the function selector we need
        ////////////////////////////////////////////
        //  swap(
        //        PoolKey memory key,
        //        SwapParams memory params,
        //        bytes calldata hookData //
        //     )

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            // read the hook address and insta store it to keep stack smaller
            mstore(add(ptr, 132), shr(96, calldataload(currentOffset)))
            // skip hook
            currentOffset := add(currentOffset, 20)
            // read the pool address
            let pool := calldataload(currentOffset)
            // skip pool plus params
            currentOffset := add(currentOffset, 29)

            // let tickSpacing := and(UINT24_MASK, shr(48, pool))
            // pay flag
            tempVar := and(UINT8_MASK, shr(40, pool))
            let clLength := and(UINT16_MASK, shr(24, pool))

            // Prepare external call data
            // Store swap selector
            mstore(ptr, SWAP)

            /** PoolKey  (2/2) */

            // Store fee
            mstore(add(ptr, 68), and(UINT24_MASK, shr(72, pool)))

            // Store tickSpacing
            mstore(add(ptr, 100), and(UINT24_MASK, shr(48, pool)))

            pool := shr(
                96,
                pool // starts as first param
            )

            // Store data offset
            mstore(add(ptr, 260), 0x120)
            // Store data length
            mstore(add(ptr, 292), clLength)

            /** SwapParams */

            // Store fromAmount
            mstore(add(ptr, 196), sub(0, fromAmount))

            // if xor(0, clLength) {
            //     // Store furhter calldata (add 4 to length due to fee and clLength)
            //     calldatacopy(add(ptr, 324), currentOffset, clLength)
            // }

            switch lt(tokenIn, tokenOut) // zeroForOne
            case 1 {
                // Store zeroForOne
                mstore(add(ptr, 164), 1)

                /** PoolKey  (1/2) */

                // Store ccy0
                mstore(add(ptr, 4), tokenIn)
                // Store ccy1
                mstore(add(ptr, 36), tokenOut)

                // Store sqrtPriceLimitX96
                mstore(add(ptr, 228), MIN_SQRT_RATIO)
            }
            default {
                // Store zeroForOne
                mstore(add(ptr, 164), 0)

                /** PoolKey  (1/2) */

                // Store ccy0
                mstore(add(ptr, 4), tokenOut)
                // Store ccy1
                mstore(add(ptr, 36), tokenIn)

                // Store sqrtPriceLimitX96
                mstore(add(ptr, 228), MAX_SQRT_RATIO)
            }

            // Perform the external 'swap' call
            if iszero(call(gas(), pool, 0, ptr, add(324, clLength), 0, 0)) {
                // store return value directly to free memory pointer
                // The call failed; we retrieve the exact error message and revert with it
                returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                revert(0, returndatasize()) // Revert with the error message
            }

            /**
             * Load actual deltas from pool manager
             * This is recommended in the docs
             */

            mstore(ptr, EXTTLOAD)
            mstore(add(ptr, 4), 0x20) // offset
            mstore(add(ptr, 36), 2) // array length

            mstore(0, address())
            mstore(0x20, tokenIn)
            // first key
            mstore(add(ptr, 68), keccak256(0, 0x40))
            // output token for 2nd key
            mstore(0x20, tokenOut)
            // second key
            mstore(add(ptr, 100), keccak256(0, 0x40))

            if iszero(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pool,
                    ptr,
                    132, // selector + offs + length + key0 + key1
                    ptr,
                    0x80 // output (offset, length, data0, data1)
                )
            ) {
                revert(0, 0)
            }

            mstore(ptr, mload(add(ptr, 0x60)))
            revert(ptr, 32)
        }
    }

    /**
     * @notice Parse a revert reason returned from a swap call
     * @param reason Bytes reason from revert
     * @return value Extracted amount
     */
    function parseRevertReason(bytes memory reason) private pure returns (uint256) {
        if (reason.length != 32) {
            if (reason.length != 64) revert("Unexpected error");
            // For iZi or other variants that return two values
            return abi.decode(reason, (uint256));
        }
        return abi.decode(reason, (uint256));
    }

    // /**
    //  * @notice Callback for Uniswap V3 swap
    //  * @param amount0Delta Amount of token0 delta
    //  * @param amount1Delta Amount of token1 delta
    //  * @param path Encoded path for callback
    //  */
    // function _v3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) internal pure {
    //     // Extract token addresses from path
    //     address tokenIn;
    //     address tokenOut;

    //     assembly {
    //         tokenIn := shr(96, calldataload(path.offset))
    //         tokenOut := shr(96, calldataload(add(path.offset, 20)))
    //     }

    //     // Determine which amount is payment and which is received
    //     (bool isExactInput, uint256 amountReceived) = amount0Delta > 0
    //         ? (tokenIn < tokenOut, uint256(-amount1Delta))
    //         : (tokenOut < tokenIn, uint256(-amount0Delta));

    //     // For exact input, we revert with the received amount
    //     if (isExactInput) {
    //         assembly {
    //             let ptr := mload(0x40)
    //             mstore(ptr, amountReceived)
    //             revert(ptr, 32)
    //         }
    //     } else {
    //         revert("Unsupported");
    //     }
    // }

    // // Fallback to handle swap callbacks from different pools
    // fallback() external {
    //     bytes calldata path;
    //     int256 amount0Delta;
    //     int256 amount1Delta;

    //     assembly {
    //         amount0Delta := calldataload(0x4)
    //         amount1Delta := calldataload(0x24)
    //         path.length := calldataload(0x64)
    //         path.offset := 132
    //     }

    //     _v3SwapCallback(amount0Delta, amount1Delta, path);
    // }
}
