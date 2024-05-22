// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {INativeWrapper} from "../../../interfaces/INativeWrapper.sol";
import {TokenTransfer} from "./TokenTransfer.sol";

/**
 * @title WrappedNativeHandler
 * @notice Handles wraps and unwraps
 */
abstract contract WrappedNativeHandler is TokenTransfer {
    constructor() {}

    /** WRAPPED NATIVE FUNCTIONS  */

    // deposit native and wrap
    function wrap() external payable {
        _depositNative();
    }

    // deposit native and wrap
    function wrapTo(address receiver) external payable {
        _depositNativeTo(receiver);
    }

    // unwrap wrappd native and send funds to sender
    function unwrap() external payable {
        _withdrawWrappedNativeTo(payable(msg.sender));
    }

    // unwrap wrappd native and send funds to a receiver
    function unwrapTo(address payable receiver) external payable {
        _withdrawWrappedNativeTo(receiver);
    }

    // send nativen from this to caller
    function refundNative() external payable {
        _transferEth();
    }

    // send nativen from this to receiver
    function refundNativeTo(address payable receiver) external payable {
        _transferEthTo(receiver);
    }
}
