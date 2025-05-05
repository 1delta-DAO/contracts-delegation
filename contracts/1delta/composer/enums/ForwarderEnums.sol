// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

/// @title Commands for CallForwarder
/// @notice Reduced Command Flags used to decode commands
library ForwarderCommands {
    uint256 internal constant EXT_CALL = 0x40;
    uint256 internal constant ASSET_HANDLING = 0x80;
    uint256 internal constant BRIDGING = 0xA0; // Added 0x20 to ASSET_HANDLING
}

/// @title Commands for Bridge
/// @dev Add individual bridges here
library BridgeIds {
    uint256 internal constant STARGATE_V2 = 0x00;
    uint256 internal constant ACROSS = 0x0A;
}
