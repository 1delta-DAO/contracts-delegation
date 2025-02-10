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
    /// lockerd    != 2
    /// slot to store the inExecution flag
    bytes32 private constant _IN_EXECUTION_SLOT = 0xff0471b0004632a86905e3993f5377c608866007c59224eed7731408a9f3f8b5;

    error NotInExecution();

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
                mstore(0x0, 0x0024332)
                revert(0x0, 0x4)
            }
        }
        _;
    }
}
