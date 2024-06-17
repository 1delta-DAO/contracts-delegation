// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {IERC20} from "../../../../../interfaces/IERC20.sol";
import {WithMantleStorage} from "./BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title Management/Data Viewer contract
 * @notice Allows the management to insert token and protocol data
 */
contract ManagementModule is WithMantleStorage {
    modifier onlyManagement() {
        require(ms().isManager[msg.sender], "Only management can interact.");
        _;
    }

    // STATE CHANGING FUNCTION

    // sets the initial cache
    function clearCache() external onlyManagement {
        gcs().cache = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    }

    /** ADD TOKEN SET FOR A LENDER */

    function addGeneralLenderTokens(
        address _underlying,
        address _aToken,
        address _vToken,
        address _sToken,
        uint8 _lenderId //
    ) external onlyManagement {
        bytes32 key = _getLenderTokenKey(_underlying, _lenderId);
        ls().debtTokens[key] = _vToken;
        ls().stableDebtTokens[key] = _sToken;
        ls().collateralTokens[key] = _aToken;
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

    /** NEW GETTERS */

    function getCollateralToken(address _underlying, uint8 _lenderId) external view returns (address) {
        return ls().collateralTokens[_getLenderTokenKey(_underlying, _lenderId)];
    }

    function getStableDebtToken(address _underlying, uint8 _lenderId) external view returns (address) {
        return ls().stableDebtTokens[_getLenderTokenKey(_underlying, _lenderId)];
    }

    function getDebtToken(address _underlying, uint8 _lenderId) external view returns (address) {
        return ls().debtTokens[_getLenderTokenKey(_underlying, _lenderId)];
    }

    /** TARGET FOR SWAPPING */

    function getIsValidTarget(address _target) external view returns (bool) {
        return gs().isValidTarget[_target];
    }
}
