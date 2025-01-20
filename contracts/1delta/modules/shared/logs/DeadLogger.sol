// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

/// @notice logs a dead log without any content
abstract contract DeadLogger {
    // log defininition
    event DeadLog();

    function _deadLog() internal {
        assembly {
            // selector for DeadLog()
            mstore(0x0, 0x8bb0e1d4)
            log0(0x0, 0x4)
        }
    }
}
