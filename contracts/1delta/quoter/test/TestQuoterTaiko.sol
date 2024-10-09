// SPDX-License-Identifier: GPL-2.0-or-later

import "../AggregationQuoterTaiko.sol";

pragma solidity ^0.8.27;

/**
 * Test quoter contract - exposes all internal functions
 */
contract TestQuoterTaiko is OneDeltaQuoterTaiko {
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

    function _syncClassicPairAddress(address tokenA, address tokenB) public view returns (address pair) {
        pair = super.syncClassicPairAddress(tokenA, tokenB);
    }

    function _syncStablePairAddress(address tokenA, address tokenB) public view returns (address pair) {
        pair = super.syncStablePairAddress(tokenA, tokenB);
    }

    function _syncBasePairAddress(address tokenA, address tokenB) public view returns (address pair) {
        pair = super.syncBasePairAddress(tokenA, tokenB);
    }
}
