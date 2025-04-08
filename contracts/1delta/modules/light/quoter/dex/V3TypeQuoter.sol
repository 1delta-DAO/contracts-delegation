// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DexTypeMappings} from "../../swappers/dex/DexTypeMappings.sol";

abstract contract V3TypeQuoter is Masks {
    /// @dev Transient storage variable used to check a safety condition in exact output swaps
    uint256 private amountOutCached;

    /*
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 1              | forkId               |
     * | 21     | 2              | fee                  |
     * | 23     | 2              | calldataLength       |
     * | 25     | calldataLength | calldata             |
     */
    function getV3TypeAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 currentOffset
    ) internal returns (uint256 amountOut, uint256 newOffset) {
        address pool;
        uint8 forkId;
        uint16 fee;
        uint16 config;
        bool zeroForOne;

        assembly {
            // Read pool address
            pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)

            // Read fork ID
            forkId := shr(248, calldataload(currentOffset))
            currentOffset := add(currentOffset, 1)

            // Read fee (as uint16)
            fee := shr(240, calldataload(currentOffset))
            currentOffset := add(currentOffset, 2)

            // Read config
            config := shr(240, calldataload(currentOffset))
            currentOffset := add(currentOffset, 2)

            // skip extra calldat bytes, if any
            if gt(config, 1) {
                currentOffset := add(currentOffset, config)
            }

            zeroForOne := lt(tokenIn, tokenOut)
        }

        try
            IUniswapV3Pool(pool).swap(
                address(this), // quoter
                zeroForOne,
                int256(amountIn),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO, // price limit
                abi.encodePacked(tokenIn, tokenOut) // callback data
            )
        {} catch (bytes memory reason) {
            return (_parseRevertReason(reason), currentOffset);
        }

        // should not happen!
        revert("Swap did not revert");
    }

    /**
     * @notice Parse a revert reason returned from a swap call
     * @param reason Bytes reason from revert
     * @return value Extracted amount
     */
    function _parseRevertReason(bytes memory reason) private pure returns (uint256) {
        if (reason.length != 32) {
            if (reason.length != 64) revert("Unexpected error");
            // For iZi or other variants that return two values
            return abi.decode(reason, (uint256));
        }
        return abi.decode(reason, (uint256));
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
        (bool isExactInput, uint256 amountReceived) = amount0Delta > 0
            ? (tokenIn < tokenOut, uint256(-amount1Delta))
            : (tokenOut < tokenIn, uint256(-amount0Delta));

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
}

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}
