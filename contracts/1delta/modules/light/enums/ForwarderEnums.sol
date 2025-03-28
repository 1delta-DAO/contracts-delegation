// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

/// @title Commands for CallForwarder
/// @notice Reduced Command Flags used to decode commands
library ForwarderCommands {
    uint256 internal constant EXT_CALL = 0x40;
    uint256 internal constant ASSET_HANDLING = 0x80;
}
