// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WithStorageComet, CometStorage, LibStorage, ManagementStorage} from "../storage/CometBrokerStorage.sol";

contract CometMarginTraderInit is WithStorageComet {
    function initCometMarginTrader(address _comet) external {
        require(!izs().initialized, "alrady initialized");
        izs().initialized = true;
        CometStorage storage cos = LibStorage.cometStorage();
        cos.comet[0] = _comet;
        ManagementStorage storage ms = LibStorage.managementStorage();
        ms.chief = msg.sender;
        ms.isManager[msg.sender] = true;
    }
}
