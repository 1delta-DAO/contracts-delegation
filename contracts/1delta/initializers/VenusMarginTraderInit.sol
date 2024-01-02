// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {WithVenusStorage} from "../storage/VenusStorage.sol";

contract VenusMarginTraderInit is WithVenusStorage {
    function initVenusMarginTrader(address _comptroller) external {
        require(!izs().initialized, "alrady initialized");
        izs().initialized = true;
        ls().comptroller = _comptroller;
        ms().chief = msg.sender;
        ms().isManager[msg.sender] = true;
    }
}
