// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @notice Returns the key for identifying a pool
struct PoolKey {
    /// @notice The lower currency of the pool, sorted numerically
    address currency0;
    /// @notice The higher currency of the pool, sorted numerically
    address currency1;
    /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
    uint24 fee;
    /// @notice Ticks that involve positions must be a multiple of tick spacing
    int24 tickSpacing;
    /// @notice The hooks of the pool
    address hooks;
}

struct SwapParams {
    /// Whether to swap token0 for token1 or vice versa
    bool zeroForOne;
    /// The desired input amount if negative (exactIn), or the desired output amount if positive (exactOut)
    int256 amountSpecified;
    /// The sqrt price at which, if reached, the swap will stop executing
    uint160 sqrtPriceLimitX96;
}

type BalanceDelta is int256;

contract PS {
    function swap(
        PoolKey memory key,
        SwapParams memory params,
        bytes calldata hookData //
    ) external view returns (BalanceDelta swapDelta) {}

    function swapB(
        uint256 kind,
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountGivenRaw,
        uint256 limitRaw,
        bytes calldata userData //
    ) external returns (uint256 amountCalculated, uint256 amountIn, uint256 amountOut) {}

    function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory) {}
}
