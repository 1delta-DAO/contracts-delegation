// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * Balancer V3 Vault
 */
interface IBalancerV3Vault {
    function settle(address token, uint256 amountHint) external returns (uint256 credit);

    function sendTo(address token, address to, uint256 amount) external;
}
