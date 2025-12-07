// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DexTypeMappings} from "../../swappers/dex/DexTypeMappings.sol";
import {QuoterUtils} from "./utils/QuoterUtils.sol";

abstract contract V3TypeQuoter is QuoterUtils, Masks {
    /**
     * @notice Calculates amountOut for Uniswap V3 style pools
     * @param amountIn Input amount
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param currentOffset Current position in the calldata
     * @return amountOut Output amount
     * @return newOffset Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 1              | forkId               |
     * | 21     | 2              | fee                  |
     * | 23     | 2              | calldataLength       |
     * | 25     | calldataLength | calldata             |
     */
    function _getV3TypeAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 currentOffset
    )
        internal
        returns (uint256 amountOut, uint256 newOffset)
    {
        address pool;
        bool zeroForOne;

        assembly {
            // Read pool address
            pool := calldataload(currentOffset)

            // Read config
            let clLength := and(UINT16_MASK, shr(56, pool))
            pool := shr(96, pool)

            // skip extra calldat bytes, if any
            switch lt(clLength, 2)
            case 1 { currentOffset := add(currentOffset, 25) }
            default { currentOffset := add(currentOffset, add(25, clLength)) }

            zeroForOne := lt(tokenIn, tokenOut)
        }

        try ICLPool(pool).swap(
            address(this), // quoter
            zeroForOne,
            int256(amountIn),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO, // price limit
            hex"" // callback data
        ) {} catch (bytes memory reason) {
            return (parseRevertReason(reason), currentOffset);
        }

        // should not happen!
        revert("Swap did not revert");
    }

    /**
     * @notice Calculates amountOut for Izumi pools
     * @param amountIn Input amount
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param currentOffset Current position in the calldata
     * @return amountOut Output amount
     * @return newOffset Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 1              | forkId               |
     * | 21     | 2              | fee                  |
     * | 23     | 2              | calldataLength       |
     * | 25     | calldataLength | calldata             |
     */
    function _getIzumiAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 currentOffset
    )
        internal
        returns (uint256 amountOut, uint256 newOffset)
    {
        address pool;
        bool zeroForOne;
        assembly {
            // Read pool address
            pool := calldataload(currentOffset)

            // Read config
            let clLength := and(UINT16_MASK, shr(56, pool))
            pool := shr(96, pool)

            // skip extra calldat bytes, if any
            switch lt(clLength, 2)
            case 1 { currentOffset := add(currentOffset, 25) }
            default { currentOffset := add(currentOffset, add(25, clLength)) }

            zeroForOne := lt(tokenIn, tokenOut)
        }

        if (tokenIn < tokenOut) {
            int24 boundaryPoint = -799999;
            try ICLPool(pool).swapX2Y(
                address(this), // address(0) might cause issues with some tokens
                uint128(amountIn),
                boundaryPoint,
                hex""
            ) {} catch (bytes memory reason) {
                return (parseRevertReason(reason), currentOffset);
            }
        } else {
            int24 boundaryPoint = 799999;
            try ICLPool(pool).swapY2X(
                address(this), // address(0) might cause issues with some tokens
                uint128(amountIn),
                boundaryPoint,
                hex""
            ) {} catch (bytes memory reason) {
                return (parseRevertReason(reason), currentOffset);
            }
        }

        // should not happen!
        revert("Swap did not revert");
    }

    // Fallback to handle swap callbacks from different pools
    fallback() external {
        assembly {
            let amount0Delta := calldataload(0x4)
            let amountReceived
            switch sgt(amount0Delta, 0)
            case 0 { amountReceived := sub(0, amount0Delta) }
            default { amountReceived := sub(0, calldataload(0x24)) }
            // revert with val
            mstore(0x0, amountReceived)
            revert(0x0, 32)
        }
    }

    function swapY2XCallback(uint256 x, uint256, bytes calldata) external pure {
        assembly {
            mstore(0x0, x)
            revert(0x0, 64)
        }
    }

    function swapX2YCallback(uint256, uint256 y, bytes calldata) external pure {
        assembly {
            mstore(0x0, y)
            revert(0x0, 64)
        }
    }
}

interface ICLPool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    )
        external
        returns (int256 amount0, int256 amount1);

    /**
     * IZUMI
     */
    function swapY2X(
        // exact in swap token1 to 0
        address recipient,
        uint128 amount,
        int24 highPt,
        bytes calldata data
    )
        external
        returns (uint256 amountX, uint256 amountY);

    function swapX2Y(
        // exact in swap token0 to 1
        address recipient,
        uint128 amount,
        int24 lowPt,
        bytes calldata data
    )
        external
        returns (uint256 amountX, uint256 amountY);
}
