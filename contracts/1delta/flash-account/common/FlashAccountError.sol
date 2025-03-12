// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

error ArrayLengthMismatch();
error ZeroAddress();
error ZeroAmount();
error MintFailed(uint256 failureCode);
error RepayFailed(uint256 failureCode);
error CantRepaySelf();
error TransferFailed();
error NotEnoughBalance();
