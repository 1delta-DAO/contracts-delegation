// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {ComposerCommands} from "../enums/DeltaEnums.sol";
import {Transfers} from "../transfers/Transfers.sol";
import {ExternalCallsGeneric} from "../generic/ExternalCallsGeneric.sol";
import {BridgeForwarder} from "./bridges/BridgeForwarder.sol";
/**
 * @notice An arbitrary call contract to forward generic calls
 * Does pull funds if desired
 * One transfers funds to this contract and operates with them, ideally pre-funded
 * All composer transfer options are available (approve,transferFrom,transfer,native transfers)
 * Can generically call any target and checks if the selector for these calls is not `transferFrom`
 * We assume that this contract is never an approve target!
 */

contract CallForwarder is Transfers, ExternalCallsGeneric, BridgeForwarder {
    // base receive function
    receive() external payable {}

    /**
     * A selector different to the classic Composer
     * Should be called by a more universal composer
     * that cannot call arbitrary selectors.
     */
    function deltaForwardCompose(bytes calldata) external payable {
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
            if (operation == ComposerCommands.EXT_CALL) {
                currentOffset = _callExternal(currentOffset);
            } else if (operation == ComposerCommands.TRANSFERS) {
                currentOffset = _transfers(currentOffset, callerAddress);
            } else if (operation == ComposerCommands.BRIDGING) {
                currentOffset = _bridge(currentOffset);
            }
            // break criteria - we shifted to the end of the calldata
            if (currentOffset >= maxIndex) break;
        }
    }
}
