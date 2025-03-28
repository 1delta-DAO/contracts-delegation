// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

/**
 * AssetHandling classifier enums
 */
library AssetHandlingIds {
    uint256 internal constant TRANSFER_FROM = 0;
    uint256 internal constant SWEEP = 1;
    uint256 internal constant WRAP_NATIVE = 2;
    uint256 internal constant UNWRAP_WNATIVE = 3;
    uint256 internal constant APPROVE = 5;
}

/// @title Commands for CallForwarder
/// @notice Reduced Command Flags used to decode commands
library ForwarderCommands {
    uint256 internal constant EXT_CALL = 0x40;
    uint256 internal constant ASSET_HANDLING = 0x80;
}
