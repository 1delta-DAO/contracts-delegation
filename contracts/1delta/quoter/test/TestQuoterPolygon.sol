// SPDX-License-Identifier: GPL-2.0-or-later

import "../AggregationQuoterPolygon.sol";

pragma solidity ^0.8.26;

/**
 * Test quoter contract - exposes all internal functions
 */
contract TestQuoterPolygon is OneDeltaQuoterPolygon {
    function _quoteKTXExactIn(address _tokenIn, address _tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteKTXExactIn(_tokenIn, _tokenOut, amountIn);
    }

    function _quoteWooFiExactIn(address _tokenIn, address _tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteWOO(_tokenIn, _tokenOut, amountIn);
    }

    /// @dev Returns the pool for the given token pair and fee.
    /// The pool contract may or may not exist.
    function _v3TypePool(address tokenA, address tokenB, uint24 fee, uint256 _pId) public pure returns (address pool) {
        return address(super.v3TypePool(tokenA, tokenB, fee, _pId));
    }

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function _getiZiPool(address tokenA, address tokenB, uint24 fee) public pure returns (address pool) {
        return address(super.getiZiPool(tokenA, tokenB, fee));
    }

    /// @dev gets uniswapV2 (and fork) pair addresses
    function _v2TypePairAddress(address tokenA, address tokenB, uint256 _pId) public pure returns (address pair) {
        return super.v2TypePairAddress(tokenA, tokenB, _pId);
    }

    /// @dev calculate amountOut for uniV2 style pools - does not require overflow checks
    function _getAmountOutUniV2Type(
        address pair,
        address tokenIn, // only used for solidly forks
        address tokenOut,
        uint256 sellAmount,
        uint256 _pId // to identify the fee
    ) public view returns (uint256 buyAmount) {
        return
            super.getAmountOutUniV2Type(
                pair,
                tokenIn, // only used for solidly forks
                tokenOut,
                sellAmount,
                _pId // to identify the fee
            );
    }

    function _quoteWOO(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteWOO(tokenIn, tokenOut, amountIn);
    }

    /// @dev calculates the input amount for a UniswapV2 style swap - requires overflow checks
    function _getV2AmountInDirect(
        address pair,
        address tokenIn, // some DEXs are more efficiently queried directly
        address tokenOut,
        uint256 buyAmount,
        uint256 pId // poolId
    ) internal view returns (uint256 x) {
        return
            super.getV2AmountInDirect(
                pair,
                tokenIn, // some DEXs are more efficiently queried directly
                tokenOut,
                buyAmount,
                pId // poolId
            );
    }
}
