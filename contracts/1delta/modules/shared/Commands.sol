// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

/// @title Commands for OneDeltaComposer
/// @notice Command Flags used to decode commands, these are provided in 4 blocks
library Commands {
    // Command Types where value<0x10, executed in the first nested-if block
    uint256 constant SWAP_EXACT_IN = 0x00;
    uint256 constant SWAP_EXACT_OUT = 0x01;
    uint256 constant FLASH_SWAP_EXACT_IN = 0x02;
    uint256 constant FLASH_SWAP_EXACT_OUT = 0x03;
    uint256 constant EXTERNAL_CALL = 0x04;

    // Command Types where 0x10<=value<0x20, executed in the second nested-if block
    uint256 constant DEPOSIT = 0x10;
    uint256 constant BORROW = 0x11;
    uint256 constant REPAY = 0x12;
    uint256 constant WITHDRAW = 0x13;

    // Command Types where 0x20<=value<0x30, executed in the third nested-if block
    uint256 constant TRANSFER_FROM = 0x21;
    uint256 constant SWEEP = 0x22;
    uint256 constant WRAP_NATIVE = 0x23;
    uint256 constant UNWRAP_WNATIVE = 0x24;
    uint256 constant PERMIT2_TRANSFER_FROM = 0x25;

    // Command Types where 0x30<=value<0x40, executed in the fourth nested-if block
    uint256 constant CALL_ON_VALID_TARGET = 0x31;
    uint256 constant EXEC_PERMIT = 0x32;
    uint256 constant EXEC_CREDIT_PERMIT = 0x33;
    uint256 constant FLASH_LOAN = 0x34;
}
