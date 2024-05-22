// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {WithStorage} from "../../storage/BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title Management/Data Viewer contract
 * @notice Allows the management to insert token and protocol data
 */
contract ManagementModule is WithStorage {
    modifier onlyManagement() {
        require(ms().isManager[msg.sender], "Only management can interact.");
        _;
    }

    function clearCache() external onlyManagement {
        gcs().cache = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    }

    // STATE CHANGING FUNCTION

    /** DEPRECATED SINGLE_LENDER FUNCTIONS */

    function addAToken(address _underlying, address _aToken) external onlyManagement {
        aas().aTokens[_underlying] = _aToken;
    }

    function addSToken(address _underlying, address _sToken) external onlyManagement {
        aas().sTokens[_underlying] = _sToken;
    }

    function addVToken(address _underlying, address _vToken) external onlyManagement {
        aas().vTokens[_underlying] = _vToken;
    }

    function addLenderTokens(address _underlying, address _aToken, address _vToken, address _sToken) external onlyManagement {
        address asset = _underlying;
        aas().vTokens[asset] = _vToken;
        aas().sTokens[asset] = _sToken;
        aas().aTokens[asset] = _aToken;
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

    /** DEPRECATED */

    function getLendingPool() external view returns (address pool) {
        pool = aas().lendingPool;
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
