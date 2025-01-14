// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {IERC20} from "../../../../interfaces/IERC20.sol";
import {WithBrokerStorage} from "./BrokerStorage.sol";
import {Slots} from "./Slots.sol";

// solhint-disable max-line-length

/**
 * @title Management/Data Viewer contract
 * @notice Allows the owner to insert token and lending protocol data
 *         Due to contract size limitations this is a separate contract
 */
contract ManagementModule is WithBrokerStorage, Slots {
    modifier onlyOwner() {
        require(ms().contractOwner == msg.sender, "Only owner can interact.");
        _;
    }

    // STATE CHANGING FUNCTION

    /** ADD TOKEN SET FOR A LENDER */

    struct BatchAddLenderTokensParams {
        address underlying;
        address collateralToken;
        address debtToken;
        address stableDebtToken;
        uint16 lenderId;
    }

    // add lender tokens in batch
    function batchAddGeneralLenderTokens(
        BatchAddLenderTokensParams[] memory lenderParams //
    ) external onlyOwner {
        for (uint256 i = 0; i < lenderParams.length; i++) {
            BatchAddLenderTokensParams memory params = lenderParams[i];
            bytes32 key = _getLenderTokenKey(params.underlying, params.lenderId);
            ls().collateralTokens[key] = params.collateralToken;
            ls().debtTokens[key] = params.debtToken;
            ls().stableDebtTokens[key] = params.stableDebtToken;
        }
    }

    function addGeneralLenderTokens(
        address _underlying,
        address _aToken,
        address _vToken,
        address _sToken,
        uint16 _lenderId //
    ) external onlyOwner {
        bytes32 key = _getLenderTokenKey(_underlying, _lenderId);
        ls().debtTokens[key] = _vToken;
        ls().stableDebtTokens[key] = _sToken;
        ls().collateralTokens[key] = _aToken;
    }

    struct ApproveParams {
        address token;
        address target;
    }

    // approve tokens and targets
    function batchApprove(ApproveParams[] memory approveParams) external onlyOwner {
        for (uint256 i = 0; i < approveParams.length; i++) {
            IERC20(approveParams[i].token).approve(approveParams[i].target, type(uint256).max);
        }
    }

    struct TargetParams {
        address target;
        bool value;
    }

    // approve tokens and targets
    function batchSetValidTarget(TargetParams[] memory targetParams) external onlyOwner {
        for (uint256 i = 0; i < targetParams.length; i++) {
            cms().isValid[targetParams[i].target] = targetParams[i].value;
        }
    }

    function addLendingPool(
        address _poolAddress,
        uint16 _lenderId //
    ) external onlyOwner {
        ls().lendingPools[_lenderId] = _poolAddress;
    }

    function setValidTarget(address _target, bool value) external onlyOwner {
        cms().isValid[_target] = value;
    }

    function approveAddress(address[] memory assets, address target) external onlyOwner {
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(target, type(uint256).max);
        }
    }

    function decreaseAllowance(address[] memory assets, address target) external onlyOwner {
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(target, 0);
        }
    }

    // VIEW FUNCTIONS

    /** NEW GETTERS */

    function getIsValidTarget(address _target) external view returns (bool) {
        return cms().isValid[_target];
    }

    function getCollateralToken(address _underlying, uint16 _lenderId) external view returns (address) {
        return ls().collateralTokens[_getLenderTokenKey(_underlying, _lenderId)];
    }

    function getStableDebtToken(address _underlying, uint16 _lenderId) external view returns (address) {
        return ls().stableDebtTokens[_getLenderTokenKey(_underlying, _lenderId)];
    }

    function getDebtToken(address _underlying, uint16 _lenderId) external view returns (address) {
        return ls().debtTokens[_getLenderTokenKey(_underlying, _lenderId)];
    }

    /** TARGET FOR SWAPPING */

    function getLendingPool(uint16 _lenderId) external view returns (address pool) {
        // equivalent to
        // return ls().lendingPools[_lenderId];
        assembly {
            mstore(0x0, _lenderId)
            mstore(0x20, LENDING_POOL_SLOT)
            pool := sload(keccak256(0x0, 0x40))
        }
    }
}
