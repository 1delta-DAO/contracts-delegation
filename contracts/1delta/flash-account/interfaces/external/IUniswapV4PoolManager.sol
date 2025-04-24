// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * Uniswap V4 PoolManager
 */
interface IUniswapV4PoolManager {
    function sync(address currency) external;

    function take(address currency, address to, uint256 amount) external;

    function settle() external payable returns (uint256 paid);

    function exttload(bytes32 slot) external view returns (bytes32 value);
}
