// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {WithStorageComet} from "../../storage/CometBrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title AAVE management contract
 * @notice allows the management of AAVE V3 protocol data
 * @author Achthar
 */
contract CometManagementModule is WithStorageComet {
    modifier onlyManagement() {
        require(ms().isManager[msg.sender], "Only management can interact.");
        _;
    }

    // STATE SETTERS

    function addComet(address _comet, uint8 _id) external onlyManagement {
        cos().comet[_id] = _comet;
    }

    function approveComet(address[] memory assets, uint8 _cometId) external onlyManagement {
        address comet = cos().comet[_cometId];
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(comet, type(uint256).max);
        }
    }

    // VIEW FUNCTIONS

    function getComet(uint8 _id) external view returns (address pool) {
        pool = cos().comet[_id];
    }
}
