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
    /**
     * Fallback that takes direct composer-like instructions, only for
     * safe transfers and non-`transferFrom` generic calls
     *
     * Note: This contract should not trigger callbacks of any kind as the calls are not abi encoded
     */
    fallback() external payable {
        uint256 currentOffset; // = 0
        // data loop paramters
        uint256 maxIndex;
        assembly {
            maxIndex := shr(240, calldataload(0))
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
                currentOffset = _transfers(currentOffset, msg.sender);
            }
            // break criteria - we shifted to the end of the calldata
            if (currentOffset >= maxIndex) break;
        }
    }
}
