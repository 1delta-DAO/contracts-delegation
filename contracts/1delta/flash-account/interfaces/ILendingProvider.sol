// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ILendingProvider {
    event Supplied(address indexed account, address indexed token, uint256 amount);
    event Withdrawn(address indexed account, address indexed token, uint256 amount);
    event Borrowed(address indexed account, address indexed token, uint256 amount);
    event Repaid(address indexed account, address indexed token, uint256 amount);

    // function supply(address token, uint256 amount) external;
    // function withdraw(address token, uint256 amount) external;
    // function borrow(address token, uint256 amount) external;
    // function repay(address token, uint256 amount) external;
}
