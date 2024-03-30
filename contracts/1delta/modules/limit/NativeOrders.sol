// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

import "./BatchFillNativeOrders.sol";

/// @dev Feature for interacting with limit, OTC and RFQ orders.
contract NativeOrders is BatchFillNativeOrders {
    constructor(
        address protocolFeeCollector,
        uint32 protocolFeeMultiplier
    ) BatchFillNativeOrders(protocolFeeCollector, protocolFeeMultiplier) {}
}
