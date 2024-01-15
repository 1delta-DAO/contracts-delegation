// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.23;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {INativeWrapper} from "../../../interfaces/INativeWrapper.sol";
import {TokenTransfer} from "../../../libraries/TokenTransfer.sol";

// solhint-disable max-line-length

/**
 * @title WrappedNativeHandler
 * @notice Handles wrap, unwrap and validations
 */
abstract contract WrappedNativeHandler is TokenTransfer {
    address private constant wrappedNative = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;

    constructor() {}

    /** WRAPPED NATIVE FUNCTIONS  */

    // deposit native and wrap
    function wrap() external payable {
        uint256 providedNative = msg.value;
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        _weth.deposit{value: providedNative}();
    }

    // unwrap wrappd native and send funds to sender
    function unwrap() external payable {
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        uint256 balance = _weth.balanceOf(address(this));
        _weth.withdraw(balance);
        // transfer eth to sender
        _transferEth(msg.sender, balance);
    }

    // unwrap wrappd native and send funds to a receiver
    function unwrapTo(address payable receiver) external payable {
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        uint256 balance = _weth.balanceOf(address(this));
        _weth.withdraw(balance);
        // transfer eth to receiver
        _transferEth(receiver, balance);
    }

    // unwrap wrappd native, validate balance and send to sender
    function validateAndUnwrap(uint256 amountMin) external payable {
        INativeWrapper _weth = INativeWrapper(wrappedNative);
        uint256 balance = _weth.balanceOf(address(this));
        require(balance >= amountMin, "Insufficient Sweep");
        _weth.withdraw(balance);
        // transfer eth to sender
        _transferEth(msg.sender, balance);
    }
}
