// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.23;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {LendingOps, IERC20} from "./VenusOps.sol";
import {TokenTransfer} from "../../../../libraries/TokenTransfer.sol";

// solhint-disable max-line-length

/**
 * @title FlashAggregator for Venus
 * @notice Adds money market and default transfer functions to margin trading
 */
contract VenusFlashAggregatorBNB is LendingOps, TokenTransfer {
    constructor() LendingOps() {}

    function deposit(address underlying, uint amount) external {
        _transferERC20TokensFrom(underlying, msg.sender, address(this), amount);
        _deposit(underlying, amount, msg.sender);
    }

    function withdraw(address underlying, uint amount) external {
        _withdraw(underlying, amount, msg.sender, msg.sender);
    }

    function borrow(address underlying, uint amount) external {
        _borrow(underlying, amount, msg.sender, msg.sender);
    }

    function repay(address underlying, uint amount) external {
        _transferERC20TokensFrom(underlying, msg.sender, address(this), amount);
        _repay(underlying, amount, msg.sender);
    }
}
