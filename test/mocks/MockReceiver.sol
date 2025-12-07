// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockReceiver {
    bool public canReceiveNative;

    constructor(bool _canReceiveNative) {
        canReceiveNative = _canReceiveNative;
    }

    receive() external payable {
        require(canReceiveNative, "Cannot receive native");
    }
}
