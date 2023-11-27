// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.23;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {INativeWrapper} from "../../../../interfaces/INativeWrapper.sol";

// solhint-disable max-line-length

/**
 * @title WrappedNativeHandler
 * @notice Handles wrap, unwrap and validations
 */
abstract contract WrappedNativeHandler {
    // constant
    address private constant wrappedNative = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    constructor() {}

    /** WRAPPED NATIVE FUNCTIONS  */

    // deposit native and wrap
    function wrap() external payable {
        uint256 supplied = msg.value;
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        _weth.deposit{value: supplied}();
    }

    // unwrap wrappd native and send funds to sender
    function unwrap() external payable {
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        uint256 balance = _weth.balanceOf(address(this));
        _weth.withdraw(balance);
        // transfer eth to sender
        payable(msg.sender).transfer(balance);
    }

    // unwrap wrappd native and send funds to a receiver
    function unwrapTo(address payable receiver) external payable {
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        uint256 balance = _weth.balanceOf(address(this));
        _weth.withdraw(balance);
        // transfer eth to receiver
        receiver.transfer(balance);
    }

    // unwrap wrappd native, validate balance and send to sender
    function validateAndUnwrap(uint256 amountMin) external payable {
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        uint256 balance = _weth.balanceOf(address(this));
        require(balance >= amountMin, "Insufficient Sweep");
        _weth.withdraw(balance);
        // transfer eth to sender
        payable(msg.sender).transfer(balance);
    }
}
