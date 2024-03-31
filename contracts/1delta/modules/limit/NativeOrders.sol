// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

import "./OtcOrders.sol";

/// @dev Feature for interacting with limit, OTC and RFQ orders.
contract NativeOrders is OtcOrders {
    constructor(
        address weth,
        address protocolFeeCollector,
        uint32 protocolFeeMultiplier
    ) OtcOrders(weth, protocolFeeCollector, protocolFeeMultiplier) {}
}
