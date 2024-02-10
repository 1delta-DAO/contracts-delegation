// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {IERC20Balance} from "../../../interfaces/IERC20Balance.sol";
import {WrappedNativeHandler} from "./WrappedNativeHandler.sol";
import {SelfPermit} from "../../base/SelfPermit.sol";
import {ILendingPool} from "./ILendingPool.sol";
import {WithStorage} from "../../../storage/BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title LendingInterface
 * @notice Adds money market and default transfer functions to margin trading - also includes permits
 */
contract DeltaLendingInterfaceMantle is WithStorage, WrappedNativeHandler, SelfPermit {
    // constant pool
    ILendingPool internal constant _lendingPool = ILendingPool(0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3);

    constructor() {}

    /** BASE LENDING FUNCTIONS */

    // deposit ERC20 to Aave on behalf of recipient
    function deposit(address asset, address recipient) external payable {
        address _asset = asset;
        uint256 balance = IERC20Balance(_asset).balanceOf(address(this));
        _lendingPool.deposit(_asset, balance, recipient, 0);
    }

    // borrow on sender's behalf
    function borrow(address asset, uint256 amount, uint256 interestRateMode) external payable {
        _lendingPool.borrow(asset, amount, interestRateMode, 0, msg.sender);
    }

    // wraps the repay function
    function repay(address asset, address recipient, uint256 interestRateMode) external payable {
        address _asset = asset;
        uint256 _balance = IERC20Balance(_asset).balanceOf(address(this));
        uint256 _debtBalance;
        uint256 _interestRateMode = interestRateMode;
        if (_interestRateMode == 2) _debtBalance = IERC20Balance(aas().vTokens[_asset]).balanceOf(msg.sender);
        else _debtBalance = IERC20Balance(aas().sTokens[_asset]).balanceOf(msg.sender);
        // if the amount lower higher than the balance, repay the amount
        if (_debtBalance >= _balance) {
            _lendingPool.repay(_asset, _balance, _interestRateMode, recipient);
        } else {
            // otherwise, repay all - make sure to call sweep afterwards
            _lendingPool.repay(_asset, _debtBalance, _interestRateMode, recipient);
        }
    }

    // wraps the withdraw
    function withdraw(address asset, address recipient) external payable {
        _lendingPool.withdraw(asset, type(uint256).max, recipient);
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
            IERC20Balance(_asset).balanceOf(msg.sender) // transfer entire balance
        );
    }

    /** @notice transfer an a balance to the sender */
    function sweep(address asset) external payable {
        address _asset = asset;
        uint256 balance = IERC20Balance(_asset).balanceOf(address(this));
        if (balance > 0) _transferERC20Tokens(_asset, msg.sender, balance);
    }

    /** @notice transfer an a balance to the recipient */
    function sweepTo(address asset, address recipient) external payable {
        address _asset = asset;
        uint256 balance = IERC20Balance(_asset).balanceOf(address(this));
        if (balance > 0) _transferERC20Tokens(_asset, recipient, balance);
    }

    function refundNative() external payable {
        uint256 balance = address(this).balance;
        if (balance > 0) _transferEth(msg.sender, balance);
    }

    /** GENERIC CALL WRAPPER FOR APPROVED CALLS */

    // call an approved target (can also be the contract itself)
    function callTarget(address target, bytes calldata params) external payable {
        address _target = target;
        require(gs().isValidTarget[_target], "Target()");
        (bool success, ) = _target.call(params);
        require(success, "CallFailed()");
    }
}
