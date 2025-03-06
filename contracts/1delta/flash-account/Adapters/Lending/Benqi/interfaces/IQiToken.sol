// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IQiToken {
    function mint(uint256 mintAmount) external returns (uint256);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
}
