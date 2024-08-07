// SPDX-License-Identifier: GPL-2.0-or-later

import "../AggregationQuoterMantle.sol";

pragma solidity ^0.8.26;

/**
 * Test quoter contract - exposes all internal functions
 */
contract TestQuoterMantle is OneDeltaQuoterMantle {
    function _quoteKTXExactIn(address _tokenIn, address _tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteKTXExactIn(_tokenIn, _tokenOut, amountIn);
    }

    function _quoteWooFiExactIn(address _tokenIn, address _tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteWOO(_tokenIn, _tokenOut, amountIn);
    }

    function _quoteStratumGeneral(uint256 indexIn, uint256 indexOut, address pool, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteStratumGeneral(indexIn, indexOut, pool, amountIn);
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
    function _v2TypePairAddress(address tokenA, address tokenB, uint256 _pId) public view returns (address pair) {
        return super.v2TypePairAddress(tokenA, tokenB, _pId);
    }

    function _quoteWOO(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteWOO(tokenIn, tokenOut, amountIn);
    }

    function _quoteStratum3(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteStratum3(tokenIn, tokenOut, amountIn);
    }
}
