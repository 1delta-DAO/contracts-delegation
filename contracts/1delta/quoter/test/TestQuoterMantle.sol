// SPDX-License-Identifier: GPL-2.0-or-later

import "../AggregationQuoterMantle.sol";

pragma solidity ^0.8.25;

/**
 * Test quoter contract - exposes all internal functions
 */
contract TestQuoterMantle is OneDeltaQuoterMantle {
    function _quoteKTXExactIn(address _tokenIn, address _tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteKTXExactIn(_tokenIn, _tokenOut, amountIn);
    }

    function _quoteStratumEth(address _tokenIn, address _tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteStratumEth(_tokenIn, _tokenOut, amountIn);
    }

    function _quoteExactInputSingleV3(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint8 pId, // pool identifier
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        return
            super.quoteExactInputSingleV3(
                tokenIn,
                tokenOut,
                fee,
                pId, // pool identifier
                amountIn
            );
    }

    function _quoteExactInputSingle_iZi(
        // no pool identifier
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint128 amount
    ) public returns (uint256 amountOut) {
        return
            super.quoteExactInputSingle_iZi(
                // no pool identifier
                tokenIn,
                tokenOut,
                fee,
                amount
            );
    }

    function _quoteExactOutputSingleV3(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint8 poolId,
        uint256 amountOut
    ) public returns (uint256 amountIn) {
        return super.quoteExactOutputSingleV3(tokenIn, tokenOut, fee, poolId, amountOut);
    }

    function _quoteExactOutputSingle_iZi(
        // no pool identifier, using `desire` functions fir exact out
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint128 desire
    ) public returns (uint256 amountIn) {
        return
            super.quoteExactOutputSingle_iZi(
                // no pool identifier, using `desire` functions fir exact out
                tokenIn,
                tokenOut,
                fee,
                desire
            );
    }

    function _getLBAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint16 binStep // identifies the exact pair address
    ) public view returns (uint256 amountOut) {
        return
            super.getLBAmountOut(
                tokenIn,
                tokenOut,
                amountIn,
                binStep // identifies the exact pair address
            );
    }

    function _getLBAmountIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint16 binStep // this param identifies the pair
    ) public view returns (uint256 amountIn) {
        return
            super.getLBAmountIn(
                tokenIn,
                tokenOut,
                amountOut,
                binStep // this param identifies the pair
            );
    }

    /// @dev Returns the pool for the given token pair and fee.
    /// The pool contract may or may not exist.
    function _v3TypePool(address tokenA, address tokenB, uint24 fee, uint256 _pId) public pure returns (ISwapPool pool) {
        return super.v3TypePool(tokenA, tokenB, fee, _pId);
    }

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function _getiZiPool(address tokenA, address tokenB, uint24 fee) public pure returns (IiZiSwapPool pool) {
        return super.getiZiPool(tokenA, tokenB, fee);
    }

    /// @dev gets uniswapV2 (and fork) pair addresses
    function _v2TypePairAddress(address tokenA, address tokenB, uint256 _pId) public view returns (address pair) {
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

    function _quoteStratum3(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        return super.quoteStratum3(tokenIn, tokenOut, amountIn);
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
