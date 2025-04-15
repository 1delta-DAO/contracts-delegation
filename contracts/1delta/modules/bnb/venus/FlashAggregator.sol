// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {LendingOps} from "./VenusOps.sol";

// solhint-disable max-line-length

/**
 * @title FlashAggregator for Venus
 * @notice Adds money market and default transfer functions to margin trading
 */
contract VenusFlashAggregatorBNB is LendingOps {
    constructor() LendingOps() {}

    function deposit(address underlying, uint256 amount) external {
        _deposit(underlying, amount, msg.sender);
    }

    function withdraw(address underlying, uint256 amount) external {
        _withdraw(underlying, amount, msg.sender, msg.sender);
    }

    function borrow(address underlying, uint256 amount) external {
        _borrow(underlying, amount, msg.sender, msg.sender);
    }

    function repay(address underlying, uint256 amount) external {
        _repay(underlying, amount, msg.sender);
    }
}
