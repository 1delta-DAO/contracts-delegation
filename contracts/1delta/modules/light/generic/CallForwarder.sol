// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {ForwarderCommands} from "../enums/ForwarderEnums.sol";
import {Transfers} from "../transfers/Transfers.sol";
import {ExternalCallsGeneric} from "../generic/ExternalCallsGeneric.sol";

/**
 * @notice An arbitrary call contract
 * Does pull funds if desired
 * One transfers funds to this contract and ooperates with them
 * Can generically call any target and checks if the selector for these calls is not `transferFrom`
 */
contract CallForwarder is Transfers, ExternalCallsGeneric {
    // base receive function
    receive() external payable {}

    /**
     * A selector different to the classic Composer
     * Should be called by a composer
     */
    function deltaComposeLevel2(bytes calldata) external payable {
        uint256 currentOffset;
        // data loop paramters
        uint256 maxIndex;
        address callerAddress;
        assembly {
            maxIndex := calldataload(0x24)
            currentOffset := 0x44
            callerAddress := caller()
        }

        ////////////////////////////////////////////////////
        // Same as composer
        ////////////////////////////////////////////////////
        while (true) {
            uint256 operation;
            // fetch op metadata
            assembly {
                operation := shr(248, calldataload(currentOffset)) // last byte
                // we increment the current offset to skip the operation
                currentOffset := add(1, currentOffset)
            }
            if (operation == ForwarderCommands.EXT_CALL) {
                currentOffset = _callExternal(currentOffset);
            } else if (operation == ForwarderCommands.ASSET_HANDLING) {
                currentOffset = _transfers(currentOffset, callerAddress, 0, 0);
            }
            // break criteria - we shifted to the end of the calldata
            if (currentOffset >= maxIndex) break;
        }
    }
}
