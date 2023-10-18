// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {WithStorage} from "../../storage/BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title Lens contract for viewing the current state of the contract
 * @notice Allows users to build large margin positions with one contract interaction
 * @author Achthar
 */
contract MarginTradeDataViewerModule is WithStorage {
    function getAAVEPool() external view returns (address pool) {
        pool = aas().v3Pool;
    }

    function getAToken(address _underlying) external view returns (address) {
        return aas().aTokens[_underlying];
    }

    function getSToken(address _underlying) external view returns (address) {
        return aas().sTokens[_underlying];
    }

    function getVToken(address _underlying) external view returns (address) {
        return aas().vTokens[_underlying];
    }

    function getIsValidTarget(address _target) external view returns (bool) {
        return gs().isValidTarget[_target];
    }
}
