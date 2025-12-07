// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DexTypeMappings} from "../../swappers/dex/DexTypeMappings.sol";
import {QuoterUtils} from "./utils/QuoterUtils.sol";

interface IUniswapV4Poolmanager {
    function unlock(bytes calldata data) external returns (bytes memory);
}

abstract contract V4TypeQuoter is QuoterUtils, Masks {
    /**
     * We need all these selectors for executing a single swap
     */
    bytes32 private constant SWAP = 0xf3cd914c00000000000000000000000000000000000000000000000000000000;
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

    /**
     * @notice Calculates amountOut for Uniswap V4 style pools
     * @param fromAmount Input amount
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param currentOffset Current position in the calldata
     * @return receivedAmount Output amount
     * @return tempVar Updated calldata offset after processing
     * @custom:calldata-offset-table
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

        try IUniswapV4Poolmanager(manager).unlock(
            abi.encodePacked(
                // add quoite-relevant data
                uint128(fromAmount),
                tokenIn, //
                tokenOut,
                calldataForCallback
            )
        ) {} catch (bytes memory reason) {
            return (parseRevertReason(reason), currentOffset);
        }
        revert("Did not revert in V4 CB");
    }

    /**
     * @notice Simulates a swap on Uniswap V4 pools
     * @param fromAmount Input amount
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param currentOffset Current position in the calldata
     * @custom:calldata-offset-table
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
    )
        internal
    {
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

            /**
             * PoolKey  (2/2)
             */

            // Store fee
            mstore(add(ptr, 68), and(UINT24_MASK, shr(72, pool)))

            // Store tickSpacing
            mstore(add(ptr, 100), and(UINT24_MASK, shr(48, pool)))

            pool :=
                shr(
                    96,
                    pool // starts as first param
                )

            // Store data offset
            mstore(add(ptr, 260), 0x120)
            // Store data length
            mstore(add(ptr, 292), clLength)

            /**
             * SwapParams
             */

            // Store fromAmount
            mstore(add(ptr, 196), sub(0, fromAmount))

            if xor(0, clLength) {
                // Store furhter calldata (add 4 to length due to fee and clLength)
                calldatacopy(add(ptr, 324), currentOffset, clLength)
            }

            switch lt(tokenIn, tokenOut)
            // zeroForOne
            case 1 {
                // Store zeroForOne
                mstore(add(ptr, 164), 1)

                /**
                 * PoolKey  (1/2)
                 */

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

                /**
                 * PoolKey  (1/2)
                 */

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
            ) { revert(0, 0) }

            mstore(ptr, mload(add(ptr, 0x60)))
            revert(ptr, 32)
        }
    }
}
