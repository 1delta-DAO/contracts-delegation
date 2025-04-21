// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

interface ISwapPool {
    function swap(
        address recipient,
        bool zeroToOne,
        int256 amountRequired,
        uint160 limitSqrtPrice,
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

    function swapY2XDesireX(
        // exact out swap token1 to 0
        address recipient,
        uint128 desireX,
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

    function swapX2YDesireY(
        // exact out swap token0 to 1
        address recipient,
        uint128 desireY,
        int24 lowPt,
        bytes calldata data
    )
        external
        returns (uint256 amountX, uint256 amountY);
}

abstract contract V3TypeQuoter {
    /// @dev Transient storage variable used to check a safety condition in exact output swaps.
    uint256 private amountOutCached;
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal immutable MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal immutable MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

    // v3 forks go into the fallback
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
        // just funnel the data to the callback
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    // uniswap V3 type callback
    function _v3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) internal view {
        // we do not validate the callback since it's just a view function
        // as such, we do not need to decode poolId and fee
        address tokenIn;
        address tokenOut;
        assembly {
            tokenIn := shr(96, calldataload(path.offset)) // right shift by 12 bytes yields the 1st token
            tokenOut := shr(96, calldataload(add(path.offset, 20))) // we load starting from the 2nd token and slice the rest
        }

        (bool isExactInput, uint256 amountToPay, uint256 amountReceived) = amount0Delta > 0
            ? (tokenIn < tokenOut, uint256(amount0Delta), uint256(-amount1Delta))
            : (tokenOut < tokenIn, uint256(amount1Delta), uint256(-amount0Delta));

        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                revert(ptr, 32)
            }
        } else {
            // if the cache has been populated, ensure that the full output amount has been received
            if (amountOutCached != 0) require(amountReceived >= amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountToPay)
                revert(ptr, 32)
            }
        }
    }

    // iZi callbacks

    function swapY2XCallback(uint256 x, uint256 y, bytes calldata path) external view {
        // we do not validate the callback since it's just a view function
        // as such, we do not need to decode poolId and fee
        address tokenIn;
        address tokenOut;
        assembly {
            tokenIn := shr(96, calldataload(path.offset)) // right shift by 12 bytes yields the 1st token
            tokenOut := shr(96, calldataload(add(path.offset, 20))) // we load starting from the 2nd token and slice the rest
        }
        if (tokenIn < tokenOut) {
            // token1 is y, amount of token1 is calculated
            // called from swapY2XDesireX(...)
            if (amountOutCached != 0) require(x >= amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, y)
                revert(ptr, 64)
            }
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

    function swapX2YCallback(uint256 x, uint256 y, bytes calldata path) external view {
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
            // token1 is x, amount of token1 is calculated param
            // called from swapX2YDesireY(...)
            if (amountOutCached != 0) require(y >= amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, x)
                revert(ptr, 64)
            }
        }
    }

    /// @dev Parses a revert reason that should contain the numeric quote
    function parseRevertReason(bytes memory reason) internal pure returns (uint256) {
        if (reason.length != 32) {
            if (reason.length != 64) revert("Unexpected error");
            // iZi catches errors of length other than 64 internally
            return abi.decode(reason, (uint256));
        }
        return abi.decode(reason, (uint256));
    }

    function getV3TypeAmountOut(address tokenIn, address tokenOut, address pair, uint256 amountIn) internal returns (uint256 amountOut) {
        bool zeroForOne = tokenIn < tokenOut;

        try ISwapPool(pair).swap(
            address(this), // address(0) might cause issues with some tokens
            zeroForOne,
            int256(amountIn),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encodePacked(tokenIn, tokenOut)
        ) {} catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    function getIziAmountOut(
        // no pool identifier
        address tokenIn,
        address tokenOut,
        address pair,
        uint128 amount
    )
        internal
        returns (uint256 amountOut)
    {
        if (tokenIn < tokenOut) {
            int24 boundaryPoint = -799999;
            try ISwapPool(pair).swapX2Y(
                address(this), // address(0) might cause issues with some tokens
                amount,
                boundaryPoint,
                abi.encodePacked(tokenIn, tokenOut)
            ) {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        } else {
            int24 boundaryPoint = 799999;
            try ISwapPool(pair).swapY2X(
                address(this), // address(0) might cause issues with some tokens
                amount,
                boundaryPoint,
                abi.encodePacked(tokenIn, tokenOut)
            ) {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        }
    }

    function getV3TypeAmountIn(address tokenIn, address tokenOut, address pair, uint256 amountOut) internal returns (uint256 amountIn) {
        bool zeroForOne = tokenIn < tokenOut;

        // if no price limit has been specified, cache the output amount for comparison in the swap callback
        amountOutCached = amountOut;
        try ISwapPool(pair).swap(
            address(this), // address(0) might cause issues with some tokens
            zeroForOne,
            -int256(amountOut),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encodePacked(tokenOut, tokenIn)
        ) {} catch (bytes memory reason) {
            delete amountOutCached; // clear cache
            return parseRevertReason(reason);
        }
    }

    function getIziAmountIn(
        // no pool identifier, using `desire` functions fir exact out
        address tokenIn,
        address tokenOut,
        address pair,
        uint128 desire
    )
        internal
        returns (uint256 amountIn)
    {
        amountOutCached = desire;
        if (tokenIn < tokenOut) {
            int24 boundaryPoint = -799999;
            try ISwapPool(pair).swapX2YDesireY(
                address(this), // address(0) might cause issues with some tokens
                desire + 1,
                boundaryPoint,
                abi.encodePacked(tokenOut, tokenIn)
            ) {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        } else {
            int24 boundaryPoint = 799999;
            try ISwapPool(pair).swapY2XDesireX(
                address(this), // address(0) might cause issues with some tokens
                desire + 1,
                boundaryPoint,
                abi.encodePacked(tokenOut, tokenIn)
            ) {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        }
    }
}
