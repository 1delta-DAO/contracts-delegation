// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ILendingProvider {
    struct LendingParams {
        address caller;
        address lender; // pool, comptroller, comet, ...
        address asset;
        address collateralToken;
        uint256 amount;
        bytes params;
    }
    event Supplied(address indexed account, address indexed token, uint256 amount);
    event Withdrawn(address indexed account, address indexed token, uint256 amount);
    event Borrowed(address indexed account, address indexed token, uint256 amount);
    event Repaid(address indexed account, address indexed token, uint256 amount);

    function supply(LendingParams calldata params) external;
    function withdraw(LendingParams calldata params) external;
    function borrow(LendingParams calldata params) external;
    function repay(LendingParams calldata params) external;
    function balanceOf(address token) external view returns (uint256);
}
