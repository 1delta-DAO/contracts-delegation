// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IcToken {
    function mint(uint256 mintAmount) external returns (uint256);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint256);
    // payable functions
    function mint() external payable;
    function repayBorrow() external payable;
    function repayBorrowBehalf(address borrower) external payable;
}
