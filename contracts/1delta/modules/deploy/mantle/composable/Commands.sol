// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

/// @title Commands
/// @notice Command Flags used to decode commands
library Commands {
    // Command Types where value<0x08, executed in the first nested-if block
    uint256 constant SWAP_EXACT_IN = 0x00;
    uint256 constant SWAP_EXACT_OUT = 0x01;
    uint256 constant FLASH_SWAP_EXACT_IN = 0x02;
    uint256 constant FLASH_SWAP_EXACT_OUT = 0x03;

    uint256 constant TRANSFER = 0x05;
    uint256 constant PAY_PORTION = 0x06;
    uint256 constant COMMAND_PLACEHOLDER_0x07 = 0x07;

    // Command Types where 0x08<=value<=0x0f, executed in the second nested-if block
    uint256 constant PERMIT2_PERMIT = 0x0a;
    uint256 constant PERMIT2_TRANSFER_FROM_BATCH = 0x0d;
    uint256 constant COMMAND_PLACEHOLDER_0x0e = 0x0e;
    uint256 constant COMMAND_PLACEHOLDER_0x0f = 0x0f;

    // Command Types where 0x10<=value<0x18, executed in the third nested-if block
    uint256 constant DEPOSIT = 0x13;
    uint256 constant BORROW = 0x11;
    uint256 constant REPAY = 0x18;
    uint256 constant WITHDRAW = 0x17;

    uint256 constant TRANSFER_FROM = 0x15;
    uint256 constant SWEEP = 0x22;
    uint256 constant WRAP_NATIVE = 0x19;
    uint256 constant UNWRAP_WNATIVE = 0x20;

    uint256 constant CALL_ON_VALID_TARGET = 0x21;
    uint256 constant EXEC_PERMIT = 0x0a;
}
