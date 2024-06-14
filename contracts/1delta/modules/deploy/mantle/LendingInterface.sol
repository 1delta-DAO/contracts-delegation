// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {IERC20Balance} from "../../../interfaces/IERC20Balance.sol";
import {WrappedNativeHandler} from "./WrappedNativeHandler.sol";
import {SelfPermit} from "../../base/SelfPermit.sol";
import {ILendingPool} from "./ILendingPool.sol";
import {BaseLending} from "./BaseLending.sol";
import {WithStorage} from "../../../storage/BrokerStorage.sol";

/**
 * @title LendingInterface
 * @notice Adds money market and default transfer functions to margin trading - also includes permits
 */
contract DeltaLendingInterfaceMantle is BaseLending, WrappedNativeHandler, SelfPermit, WithStorage {
    // constant pool

    constructor() {}

    /** BASE LENDING FUNCTIONS */

    // deposit ERC20 to Aave types on behalf of recipient
    function deposit(address asset, address recipient, uint8 lenderId) external payable {
        address _asset = asset;
        uint256 balance = _balanceOfThis(_asset);
        _deposit(_asset, recipient, balance, lenderId);
    }

    // borrow on sender's behalf
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint8 lenderId) external payable {
        _borrow(asset, msg.sender, amount, interestRateMode, lenderId);
    }

    // wraps the repay function
    function repay(address asset, address recipient, uint256 interestRateMode, uint8 lenderId) external payable {
        address _asset = asset;
        uint256 _balance = _balanceOfThis(_asset);
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        if (_interestRateMode == 2) _debtBalance = _variableDebtBalance(_asset, msg.sender, lenderId);
        else _debtBalance = _stableDebtBalance(_asset, msg.sender, lenderId);
        // if the amount lower higher than the balance, repay the amount
        if (_debtBalance >= _balance) {
            _repay(_asset, recipient, _balance, interestRateMode, lenderId);
        } else {
            // otherwise, repay all - make sure to call sweep afterwards
            _repay(_asset, recipient, _debtBalance, interestRateMode, lenderId);
        }
    }

    // wraps the withdraw
    function withdraw(address asset, address recipient, uint8 lenderId) external payable {
        _withdraw(asset, recipient, type(uint256).max, lenderId);
    }

    /** TRANSFER FUNCTIONS */

    /** @notice transfer an ERC20token in */
    function transferERC20In(address asset, uint256 amount) external payable {
        _transferERC20TokensFrom(asset, msg.sender, address(this), amount);
    }

    /** @notice transfer all ERC20tokens in - only required for aTokens */
    function transferERC20AllIn(address asset) external payable {
        address _asset = asset;

        _transferERC20TokensFrom(
            _asset,
            msg.sender,
            address(this),
            _balanceOfCaller(_asset) // transfer entire balance
        );
    }

    /** @notice transfer an a balance to the sender */
    function sweep(address asset) external payable {
        address _asset = asset;
        uint256 balance = _balanceOfThis(_asset);
        if (balance > 0) _transferERC20Tokens(_asset, msg.sender, balance);
    }

    /** @notice transfer an a balance to the recipient */
    function sweepTo(address asset, address recipient) external payable {
        address _asset = asset;
        uint256 balance = _balanceOfThis(_asset);
        if (balance > 0) _transferERC20Tokens(_asset, recipient, balance);
    }


    /** GENERIC CALL WRAPPER FOR APPROVED CALLS */

    // Call to an approved target (can also be the contract itself)
    // Can be for swaps or wraps
    function callTarget(address target, bytes memory data) external payable {
        address _target = target;
        require(gs().isValidTarget[_target], "Target()");
        bool success;
        (success, data) = _target.call(data);
        if (!success) {
            if (data.length < 68) revert("Unexpected Error");
            assembly {
                data := add(data, 0x04)
            }
            revert(abi.decode(data, (string)));
        }
    }

    /** BALANCE FETCHERS */

    function _balanceOfCaller(address underlying) private view returns (uint256 callerBalance) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            let collateralToken := sload(keccak256(ptr, 0x40))
            // selector for balanceOf(address)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(add(ptr, 0x4), caller())

            // call to underlying
            pop(staticcall(gas(), underlying, ptr, 0x24, ptr, 0x20))

            callerBalance := mload(ptr)
        }
    }
}
