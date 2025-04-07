// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Slots} from "../../shared/storage/Slots.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice External call on whitelisted targets
 * This needs a whitelisting functions that stores the addresses in the correct slots
 * Do NOT whitlist lending contracts or tokens!
 */
abstract contract ExternalCallsGeneric is Slots, ERC20Selectors, Masks, DeltaErrors {
    /// @dev mask for selector in calldata
    bytes32 private constant SELECTOR_MASK = 0xffffffff00000000000000000000000000000000000000000000000000000000;

    // Forbidden()
    bytes4 private constant FORBIDDEN = 0xee90c468;

    function _callExternal(uint256 currentOffset) internal returns (uint256) {
        ////////////////////////////////////////////////////
        // Execute call to external contract. It consits of
        // an approval target and call target.
        // The combo of [approvalTarget, target] has to be whitelisted
        // for calls. Those are exclusively swap aggregator contracts.
        // An amount has to be supplied to check the allowance from
        // this contract to target.
        // NEVER whitelist a token as an attacker can call
        // `transferFrom` on target
        // Data layout:
        //      bytes 0-20:                  target
        //      bytes 20-34:                 callvalue()
        //      bytes 34-36:                 calldataLength
        //      bytes 36-(36+data length):   data
        ////////////////////////////////////////////////////
        assembly {
            // get first three addresses
            let target := shr(96, calldataload(currentOffset))

            // get msg.value for call
            let callValue := calldataload(add(currentOffset, 20))
            let dataLength := and(UINT16_MASK, shr(128, callValue))
            callValue := shr(144, callValue) // shr will already mask correctly
            if iszero(callValue) {
                callValue := selfbalance()
            }

            // free memo ptr for populating the tx
            let ptr := mload(0x40)

            ////////////////////////////////////////////////////
            // If the token is zero, we assume that it is a native
            // transfer / swap and the approval check is skipped
            ////////////////////////////////////////////////////

            // increment offset to calldata start
            currentOffset := add(36, currentOffset)

            // extract the selector from the calldata
            // and check if it is `transferFrom`
            if eq(and(SELECTOR_MASK, calldataload(currentOffset)), ERC20_TRANSFER_FROM) {
                mstore(0x0, FORBIDDEN)
                revert(0x0, 0x4)
            }

            // copy calldata
            calldatacopy(ptr, currentOffset, dataLength)
            if iszero(
                call(
                    gas(),
                    target,
                    callValue,
                    ptr, //
                    dataLength, // the length must be correct or the call will fail
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // increment offset by data length
            currentOffset := add(currentOffset, dataLength)
        }
        return currentOffset;
    }
}
