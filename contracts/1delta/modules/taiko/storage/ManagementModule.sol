// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {IERC20} from "../../../../interfaces/IERC20.sol";
import {WithTaikoStorage} from "./BrokerStorage.sol";
import {ERC20Selectors} from "../../shared//selectors/ERC20Selectors.sol";
import {Slots} from "./Slots.sol";

// solhint-disable max-line-length

/**
 * @title Management/Data Viewer contract
 * @notice Allows the owner to insert token and lending protocol data
 *         Due to contract size limitations this is a separate contract
 */
contract TaikoManagementModule is WithTaikoStorage, ERC20Selectors, Slots {
    modifier onlyOwner() {
        require(ms().contractOwner == msg.sender, "Only owner can interact.");
        _;
    }

    // STATE CHANGING FUNCTION

    // sets the initial cache
    function clearCache() external onlyOwner {
        gcs().cache = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    }

    /** ADD TOKEN SET FOR A LENDER */

    function addGeneralLenderTokens(
        address _underlying,
        address _aToken,
        address _vToken,
        address _sToken,
        uint8 _lenderId //
    ) external onlyOwner {
        bytes32 key = _getLenderTokenKey(_underlying, _lenderId);
        ls().debtTokens[key] = _vToken;
        ls().stableDebtTokens[key] = _sToken;
        ls().collateralTokens[key] = _aToken;
    }

    function addLendingPool(
        address _poolAddress,
        uint8 _lenderId //
    ) external onlyOwner {
        ls().lendingPools[_lenderId] = _poolAddress;
    }

    function setValidTarget(address _approvalTarget, address _target, bool value) external onlyOwner {
        es().isValidApproveAndCallTarget[_approvalTarget][_target] = value;
    }

    function approveAddress(address[] memory assets, address target) external onlyOwner {
        for (uint256 i = 0; i < assets.length; i++) {
            address token = assets[i];
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x4), target)
                mstore(add(ptr, 0x24), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                if iszero(call(gas(), token, 0x0, ptr, 0x44, ptr, 0x0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0x0, returndatasize())
                }
            }
        }
    }

    function decreaseAllowance(address[] memory assets, address target) external onlyOwner {
        for (uint256 i = 0; i < assets.length; i++) {
            address token = assets[i];
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x4), target)
                mstore(add(ptr, 0x24), 0x0)
                if iszero(call(gas(), token, 0x0, ptr, 0x44, ptr, 32)) {
                    revert(0x0, 0x0)
                }
            }
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

    function getIsValidTarget(address _approvalTarget, address _target) external view returns (bool val) {
        // equivalent to
        // return es().isValidApproveAndCallTarget[_approvalTarget][_target];
        assembly {
            mstore(0x0, _approvalTarget)
            mstore(0x20, EXTERNAL_CALLS_SLOT)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, _target)
            val := sload(keccak256(0x0, 0x40))
        }
    }

    function getLendingPool(uint8 _lenderId) external view returns (address pool) {
        // equivalent to
        // return ls().lendingPools[_lenderId];
        assembly {
            mstore(0x0, _lenderId)
            mstore(0x20, LENDING_POOL_SLOT)
            pool := sload(keccak256(0x0, 0x40))
        }
    }
}
