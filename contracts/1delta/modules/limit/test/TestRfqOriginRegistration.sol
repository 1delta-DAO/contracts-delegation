// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

import "../INativeOrders.sol";

contract TestRfqOriginRegistration {
    function registerAllowedRfqOrigins(INativeOrders feature, address[] memory origins, bool allowed) external {
        feature.registerAllowedRfqOrigins(origins, allowed);
    }
}
