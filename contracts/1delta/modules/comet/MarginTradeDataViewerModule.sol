// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {WithStorageComet} from "../../storage/CometBrokerStorage.sol";
import {IUniswapV3Pool} from "../../dex-tools/uniswap/core/IUniswapV3Pool.sol";
import {PoolAddress} from "../../dex-tools/uniswap/libraries/PoolAddress.sol";

// solhint-disable max-line-length

/**
 * @title MarginTrader contract
 * @notice Allows users to build large margin positions with one contract interaction
 * @author Achthar
 */
contract CometMarginTradeDataViewerModule is WithStorageComet {
    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getUniswapV3Pool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (IUniswapV3Pool) {
        return IUniswapV3Pool(PoolAddress.computeAddress(us().v3factory, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
    }

    function getFactory() external view returns (address factory) {
        factory = us().v3factory;
    }

    function getSwapRouter() external view returns (address) {
        return us().swapRouter;
    }

    function getNativeWrapper() external view returns (address) {
        return us().weth;
    }

    function getComet(uint8 _id) external view returns (address pool) {
        pool = cos().comet[_id];
    }
}
