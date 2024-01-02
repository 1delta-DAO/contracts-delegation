// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.23;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {LendingOps} from "./VenusOps.sol";

// solhint-disable max-line-length

/**
 * @title FlashAggregator for Venus
 * @notice Adds money market and default transfer functions to margin trading
 */
contract VenusFlashAggregator is LendingOps {
    // constants

    constructor(address _cNative, address _wNative) LendingOps(_cNative, _wNative) {}

    function depo(address underlying, uint amount) external {
        _deposit(underlying, amount, msg.sender);
    }
}
