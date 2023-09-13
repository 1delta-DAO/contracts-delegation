// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WithStorage, AaveStorage, LibStorage, ManagementStorage} from "../storage/BrokerStorage.sol";

contract AaveMarginTraderInit is WithStorage {
    function initAaveMarginTrader(address _aavePool) external {
        require(!izs().initialized, "alrady initialized");
        izs().initialized = true;
        AaveStorage storage aas = LibStorage.aaveStorage();
        aas.v3Pool = _aavePool;
        ManagementStorage storage ms = LibStorage.managementStorage();
        ms.chief = msg.sender;
        ms.isManager[msg.sender] = true;
    }
}
