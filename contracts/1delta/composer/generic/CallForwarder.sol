// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {ComposerCommands} from "../enums/DeltaEnums.sol";
import {Transfers} from "../transfers/Transfers.sol";
import {ExternalCallsGeneric} from "../generic/ExternalCallsGeneric.sol";
import {BridgeForwarder} from "./bridges/BridgeForwarder.sol";
import {ERC721Receiver} from "./ERC721Receiver.sol";

/**
 * @notice An arbitrary call contract to forward generic calls
 * Does pull funds if desired
 * One transfers funds to this contract and operates with them, ideally pre-funded
 * All composer transfer options are available (approve,transferFrom,transfer,native transfers)
 * Can generically call any target and checks if the selector for these calls is not `transferFrom`
 * We assume that this contract is never an approve target!
 */
contract CallForwarder is Transfers, ExternalCallsGeneric, BridgeForwarder, ERC721Receiver {
    // base receive function
    receive() external payable {}

    /**
     * A selector different to the classic Composer
     * Should be called by a more universal composer
     * that cannot call arbitrary selectors.
     */
    function deltaForwardCompose(bytes calldata) external payable {
        uint256 currentOffset;
        uint256 endOffset;
        address callerAddress;
        assembly {
            let calldataLength := calldataload(0x24)
            currentOffset := 0x44
            endOffset := add(currentOffset, calldataLength)
            callerAddress := caller()
        }
        _deltaComposeInternal(callerAddress, currentOffset, endOffset);
    }

    function _deltaComposeInternal(
        address callerAddress,
        uint256 currentOffset,
        uint256 endOffset
    )
        internal
        virtual
        override(ExternalCallsGeneric)
    {
        while (true) {
            uint256 operation;
            assembly {
                operation := shr(248, calldataload(currentOffset))
                currentOffset := add(1, currentOffset)
            }

            // external call blocks
            if (operation < ComposerCommands.TRANSFERS) {
                if (operation == ComposerCommands.EXT_CALL) {
                    currentOffset = _callExternal(currentOffset);
                } else if (operation == ComposerCommands.EXT_TRY_CALL) {
                    currentOffset = _tryCallExternal(currentOffset, callerAddress);
                } else if (operation == ComposerCommands.EXT_CALL_WITH_REPLACE) {
                    currentOffset = _callExternalWithReplace(currentOffset);
                } else if (operation == ComposerCommands.EXT_TRY_CALL_WITH_REPLACE) {
                    currentOffset = _tryCallExternalWithReplace(currentOffset, callerAddress);
                } else {
                    _invalidOperation();
                }
            } else if (operation == ComposerCommands.TRANSFERS) {
                currentOffset = _transfers(currentOffset, callerAddress);
            } else if (operation == ComposerCommands.BRIDGING) {
                currentOffset = _bridge(currentOffset);
            } else {
                _invalidOperation();
            }

            // break criteria - we reached the end of the calldata exactly
            if (currentOffset >= endOffset) break;
        }
        // revert if we went past the end
        if (currentOffset > endOffset) revert InvalidCalldata();
    }
}
