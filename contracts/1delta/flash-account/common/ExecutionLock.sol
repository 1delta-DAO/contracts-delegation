// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/**
 * @notice Module that allows setting a flag once operations are triggered
 * This is necessary for managing flash loan callbacks
 * Its strage slot needs to be fixed to prevent colissions
 */
abstract contract ExecutionLock {
    /// @notice inExecution flag is stored here:
    /// inExecution = 2
    /// locked    != 2
    /// slot to store the inExecution flag
    /// @dev this is the slot for keccak256("flash_account.lock")
    bytes32 private constant _IN_EXECUTION_SLOT = 0x3c25485dd7fcb5b79c6e101a51e4ac1d265adde8f4b2805851861db54821825d;

    /// @dev custom error for violating lok condition
    error Locked();

    /// @notice All function execution user operations
    /// need to use this modifier
    modifier setInExecution() {
        assembly {
            sstore(_IN_EXECUTION_SLOT, 2)
        }
        _;
        assembly {
            sstore(_IN_EXECUTION_SLOT, 1)
        }
    }

    // checks whether the account is in execution
    modifier requireInExecution() {
        assembly {
            if xor(2, sload(_IN_EXECUTION_SLOT)) {
                mstore(0x0, 0x0f2e5b6c00000000000000000000000000000000000000000000000000000000) // 4-byte selector padded
                revert(0x0, 0x4) // Revert with exactly 4 bytes
            }
        }
        _;
    }
}
