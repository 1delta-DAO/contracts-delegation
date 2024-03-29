// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

/// @dev a Reverter contract that reverts on custom data without
///      Solidity's revert clause
library Reverter {
    /// @dev Reverts an encoded rich revert reason `errorData`.
    /// @param errorData ABI encoded error data.
    function revertWithData(bytes memory errorData) internal pure {
        assembly {
            revert(add(errorData, 0x20), mload(errorData))
        }
    }
}
