// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice External call on call forwarder which can safely execute any calls
 * without comprimising this contract
 */
abstract contract ExternalCall is Masks, DeltaErrors {
    // this is a consistent call forwarder deployment
    address internal immutable FORWARDER;

    constructor(address _forwarder) {
        FORWARDER = _forwarder;
    }

    function _callExternal(uint256 currentOffset) internal returns (uint256) {
        address _forwarder = FORWARDER;
        ////////////////////////////////////////////////////
        // Foraward a call to callForawrder to execute unsafe
        // generic calls
        // Data layout:
        //      bytes 0-14:                  nativeValue
        //      bytes 14-16:                 calldata length
        //      bytes 16-(16+data length):   data
        ////////////////////////////////////////////////////
        assembly {
            // get msg.value for call
            let callValue := calldataload(currentOffset)
            let dataLength := and(UINT16_MASK, shr(128, callValue))
            callValue := shr(144, callValue) // shr will already mask correctly

            // free memo ptr for populating the tx
            let ptr := mload(0x40)

            ////////////////////////////////////////////////////
            // If the token is zero, we assume that it is a native
            // transfer / swap and the approval check is skipped
            ////////////////////////////////////////////////////

            // increment offset to calldata start
            currentOffset := add(14, currentOffset)

            // copy calldata
            calldatacopy(ptr, currentOffset, dataLength)
            if iszero(
                call(
                    gas(),
                    _forwarder,
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
            currentOffset := add(add(currentOffset, 2), dataLength)
        }
        return currentOffset;
    }
}
