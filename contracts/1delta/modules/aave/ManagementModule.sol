// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {WithStorage} from "../../storage/BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title Management contract
 * @notice Allows the management of to insert token and protocol data
 * @author Achthar
 */
contract ManagementModule is WithStorage {
    modifier onlyManagement() {
        require(ms().isManager[msg.sender], "Only management can interact.");
        _;
    }

    function addAToken(address _underlying, address _aToken) external onlyManagement {
        aas().aTokens[_underlying] = _aToken;
    }

    function addSToken(address _underlying, address _sToken) external onlyManagement {
        aas().sTokens[_underlying] = _sToken;
    }

    function addVToken(address _underlying, address _vToken) external onlyManagement {
        aas().vTokens[_underlying] = _vToken;
    }

    function addAaveTokens(
        address _underlying,
        address _aToken,
        address _vToken,
        address _sToken
    ) external onlyManagement {
        address asset = _underlying;
        aas().vTokens[asset] = _vToken;
        aas().sTokens[asset] = _sToken;
        aas().aTokens[asset] = _aToken;
    }

    function approveAAVEPool(address[] memory assets) external onlyManagement {
        address aavePool = aas().v3Pool;
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(aavePool, type(uint256).max);
        }
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
}
