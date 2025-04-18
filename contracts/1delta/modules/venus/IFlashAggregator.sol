// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

interface IVenusFlashAggregator {
    function deposit(address underlying, uint256 amount) external;

    function withdraw(address underlying, uint256 amount) external;

    function borrow(address underlying, uint256 amount) external;

    function repay(address underlying, uint256 amount) external;
}
