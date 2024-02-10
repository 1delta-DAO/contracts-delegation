// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IUniswapV3Pool} from "../dex-tools/uniswap/core/IUniswapV3Pool.sol";

interface IUniswapV3ProviderModule {
    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getUniswapV3Pool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (IUniswapV3Pool);
}
