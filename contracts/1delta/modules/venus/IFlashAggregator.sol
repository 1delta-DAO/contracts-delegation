// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

interface IVenusFlashAggregator {
    function deposit(address underlying, uint amount) external;

    function withdraw(address underlying, uint amount) external;

    function borrow(address underlying, uint amount) external;

    function repay(address underlying, uint amount) external;
}
