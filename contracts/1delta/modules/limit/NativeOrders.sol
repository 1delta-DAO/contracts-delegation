// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

import "./NativeOrdersSettlement.sol";

/// @dev Feature for interacting with limit and RFQ orders.
contract NativeOrders is NativeOrdersSettlement {
    /// @dev Name of this feature.
    string public constant FEATURE_NAME = "LimitOrders";
    /// @dev Version of this feature.
    uint256 public immutable FEATURE_VERSION = 1;

    constructor(
        address proxyAddress,
        address weth
    ) NativeOrdersSettlement(proxyAddress, weth) {}
}
