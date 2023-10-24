// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WithStorage, AaveStorage, LibStorage, ManagementStorage} from "../storage/BrokerStorage.sol";

contract MarginTraderInit is WithStorage {
    function initMarginTrader(address _lendlePool) external {
        require(!izs().initialized, "alrady initialized");
        izs().initialized = true;
        AaveStorage storage aas = LibStorage.aaveStorage();
        aas.lendingPool = _lendlePool;
        izs().initialized = true;
        ManagementStorage storage ms = LibStorage.managementStorage();
        ms.chief = msg.sender;
        ms.isManager[msg.sender] = true;
    }
}
