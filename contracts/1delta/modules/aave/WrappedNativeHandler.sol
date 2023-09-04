// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {INativeWrapper} from "../../interfaces/INativeWrapper.sol";

// solhint-disable max-line-length

/**
 * @title WrappedNativeHandler
 * @notice Handles wrap, unwrap and validations
 */
abstract contract WrappedNativeHandler {
    // immutable
    address private immutable wrappedNative;

    constructor(address weth) {
        wrappedNative = weth;
    }

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
