// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {WithVenusStorage} from "../../storage/VenusStorage.sol";

// solhint-disable max-line-length

/**
 * @title Management/Data Viewer contract
 * @notice Allows the management of to insert token and protocol data
 * @author Achthar
 */
contract VenusManagementModule is WithVenusStorage {
    modifier onlyManagement() {
        require(ms().isManager[msg.sender], "Only management can interact.");
        _;
    }

    // STATE CHANGING FUNCTION

    function addCollateralToken(address _underlying, address _cToken) external onlyManagement {
        ls().collateralTokens[_underlying] = _cToken;
    }

    function approveCollateralTokens(address[] memory assets) external onlyManagement {
        for (uint256 i; i < assets.length; i++) {
            address asset = assets[i];
            IERC20(asset).approve(ls().collateralTokens[asset], type(uint256).max);
        }
    }

    function setComptroller(address _comptroller) external onlyManagement {
        ls().comptroller = _comptroller;
    }

    function setValidTarget(address target, bool value) external onlyManagement {
        gs().isValidTarget[target] = value;
    }

    function approveAddress(address[] memory assets, address target) external onlyManagement {
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(target, type(uint256).max);
        }
    }

    function decreaseAllowance(address[] memory assets, address target) external onlyManagement {
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(target, 0);
        }
    }

    // VIEW FUNCTIONS

    function getComptroller() external view returns (address comptroller) {
        comptroller = ls().comptroller;
    }

    function getCollateralToken(address _underlying) external view returns (address) {
        return ls().collateralTokens[_underlying];
    }

    function getIsValidTarget(address _target) external view returns (bool) {
        return gs().isValidTarget[_target];
    }
}
