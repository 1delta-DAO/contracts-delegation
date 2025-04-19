// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DexTypeMappings} from "../../swappers/dex/DexTypeMappings.sol";
import {QuoterUtils} from "./utils/QuoterUtils.sol";

abstract contract V3TypeQuoter is QuoterUtils, Masks {
    /*
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
        uint16 config;
        bool zeroForOne;

        assembly {
            // Read pool address
            pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 23)

            // Read config
            config := shr(240, calldataload(currentOffset))
            currentOffset := add(currentOffset, 2)

            // skip extra calldat bytes, if any
            if gt(config, 1) { currentOffset := add(currentOffset, config) }

            zeroForOne := lt(tokenIn, tokenOut)
        }

        try ICLPool(pool).swap(
            address(this), // quoter
            zeroForOne,
            int256(amountIn),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO, // price limit
            abi.encodePacked(tokenIn, tokenOut) // callback data
        ) {} catch (bytes memory reason) {
            return (parseRevertReason(reason), currentOffset);
        }

        // should not happen!
        revert("Swap did not revert");
    }

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
        uint16 config;
        bool zeroForOne;

        assembly {
            // Read pool address
            pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 23)

            // Read config
            config := shr(240, calldataload(currentOffset))
            currentOffset := add(currentOffset, 2)

            // skip extra calldat bytes, if any
            if gt(config, 1) { currentOffset := add(currentOffset, config) }

            zeroForOne := lt(tokenIn, tokenOut)
        }

        if (tokenIn < tokenOut) {
            int24 boundaryPoint = -799999;
            try ICLPool(pool).swapX2Y(
                address(this), // address(0) might cause issues with some tokens
                uint128(amountIn),
                boundaryPoint,
                abi.encodePacked(tokenIn, tokenOut)
            ) {} catch (bytes memory reason) {
                return (parseRevertReason(reason), currentOffset);
            }
        } else {
            int24 boundaryPoint = 799999;
            try ICLPool(pool).swapY2X(
                address(this), // address(0) might cause issues with some tokens
                uint128(amountIn),
                boundaryPoint,
                abi.encodePacked(tokenIn, tokenOut)
            ) {} catch (bytes memory reason) {
                return (parseRevertReason(reason), currentOffset);
            }
        }

        // should not happen!
        revert("Swap did not revert");
    }

    /**
     * @notice Callback for Uniswap V3 swap
     * @param amount0Delta Amount of token0 delta
     * @param amount1Delta Amount of token1 delta
     * @param path Encoded path for callback
     */
    function _v3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) internal pure {
        // Extract token addresses from path
        address tokenIn;
        address tokenOut;

        assembly {
            tokenIn := shr(96, calldataload(path.offset))
            tokenOut := shr(96, calldataload(add(path.offset, 20)))
        }

        // Determine which amount is payment and which is received
        (bool isExactInput, uint256 amountReceived) =
            amount0Delta > 0 ? (tokenIn < tokenOut, uint256(-amount1Delta)) : (tokenOut < tokenIn, uint256(-amount0Delta));

        // For exact input, we revert with the received amount
        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                revert(ptr, 32)
            }
        } else {
            revert("Unsupported");
        }
    }

    // Fallback to handle swap callbacks from different pools
    fallback() external {
        bytes calldata path;
        int256 amount0Delta;
        int256 amount1Delta;

        assembly {
            amount0Delta := calldataload(0x4)
            amount1Delta := calldataload(0x24)
            path.length := calldataload(0x64)
            path.offset := 132
        }

        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    function swapY2XCallback(uint256 x, uint256, bytes calldata path) external pure {
        // we do not validate the callback since it's just a view function
        // as such, we do not need to decode poolId and fee
        address tokenIn;
        address tokenOut;
        assembly {
            tokenIn := shr(96, calldataload(path.offset)) // right shift by 12 bytes yields the 1st token
            tokenOut := shr(96, calldataload(add(path.offset, 20))) // we load starting from the 2nd token and slice the rest
        }
        if (tokenIn < tokenOut) {
            // exact out is unsupported
            revert("Unsupported");
        } else {
            // token0 is y, amount of token0 is input param
            // called from swapY2X(...)
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, x)
                revert(ptr, 64)
            }
        }
    }

    function swapX2YCallback(uint256, uint256 y, bytes calldata path) external pure {
        // we do not validate the callback since it's just a view function
        // as such, we do not need to decode poolId and fee
        address tokenIn;
        address tokenOut;
        assembly {
            tokenIn := shr(96, calldataload(path.offset)) // right shift by 12 bytes yields the 1st token
            tokenOut := shr(96, calldataload(add(path.offset, 20))) // we load starting from the 2nd token and slice the rest
        }
        if (tokenIn < tokenOut) {
            // token0 is x, amount of token0 is input param
            // called from swapX2Y(...)
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, y)
                revert(ptr, 64)
            }
        } else {
            // exact out is unsupported
            revert("Unsupported");
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
