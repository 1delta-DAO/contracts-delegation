// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

/**
 * @notice Module that allows setting a flag once operations are triggered
 * This is necessary for managing flash loan callbacks
 * Its storage slot needs to be fixed to prevent collisions
 */
abstract contract ExecutionLock {
    /// @notice inExecution flag is stored here:
    /// IN_EXECUTION_SLOT == caller() => locked for caller
    /// IN_EXECUTION_SLOT == type(uint256).max => not locked for any caller, can accept flash loan calls
    /// slot to store the inExecution flag
    /// @dev this is the slot for keccak256("flash_loan_module.lock")
    bytes32 private constant IN_EXECUTION_SLOT = 0x12cfb2d397d8c322044bd0ecc925788f7eda447a6b3031394cf3b7c2f759f1b0;
    uint256 private constant UINT256_MAX = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @dev custom error for violating lok condition
    error Locked();
    error AlreadyInExecution();

    function _initializeLock() internal {
        assembly {
            sstore(IN_EXECUTION_SLOT, UINT256_MAX)
        }
    }

    /// @notice All function execution user operations
    /// @dev this modifier makes to function non-reentrant too
    /// need to use this modifier
    modifier lockExecutionForCaller() {
        assembly {
            if xor(sload(IN_EXECUTION_SLOT), UINT256_MAX) {
                mstore(0x0, 0x9ef9c1d100000000000000000000000000000000000000000000000000000000) // AlreadyInExecution()
                revert(0x0, 0x4)
            }
            sstore(IN_EXECUTION_SLOT, caller())
        }
        _;
        assembly {
            sstore(IN_EXECUTION_SLOT, UINT256_MAX)
        }
    }

    modifier onlyNotInExecution() {
        assembly {
            if xor(UINT256_MAX, sload(IN_EXECUTION_SLOT)) {
                mstore(0x0, 0x9ef9c1d100000000000000000000000000000000000000000000000000000000)
                revert(0x0, 0x4)
            }
        }
        _;
    }

    // gets the caller address from the slot, reverts if not set
    function _getCallerWithLockCheck() internal view returns (address caller_) {
        assembly {
            let valueInSlot := sload(IN_EXECUTION_SLOT)
            if eq(UINT256_MAX, valueInSlot) {
                mstore(0x0, 0x0f2e5b6c00000000000000000000000000000000000000000000000000000000) // 4-byte selector padded
                revert(0x0, 0x4) // Revert with exactly 4 bytes
            }
            caller_ := valueInSlot
        }
    }
}
