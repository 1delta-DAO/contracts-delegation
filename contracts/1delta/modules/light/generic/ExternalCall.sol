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
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract ExternalCall is Slots, ERC20Selectors, Masks, DeltaErrors {
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
        //      bytes 0-20:                  token
        //      bytes 20-40:                 target
        //      bytes 40-54:                 amount
        //      bytes 54-56:                 calldata length
        //      bytes 56-(56+data length):   data
        ////////////////////////////////////////////////////
        assembly {
            // get first three addresses
            let token := shr(96, calldataload(currentOffset))
            let target := shr(96, calldataload(add(currentOffset, 20)))

            // get slot isValid[target]
            mstore(0x0, target)
            mstore(0x20, CALL_MANAGEMENT_VALID)
            // validate target
            if iszero(sload(keccak256(0x0, 0x40))) {
                mstore(0, INVALID_TARGET)
                revert(0, 0x4)
            }
            // get amount to check allowance
            let amount := calldataload(add(currentOffset, 40))
            let dataLength := and(UINT16_MASK, shr(128, amount))
            amount := shr(144, amount) // shr will already mask correctly

            // free memo ptr for populating the tx
            let ptr := mload(0x40)

            ////////////////////////////////////////////////////
            // If the token is zero, we assume that it is a native
            // transfer / swap and the approval check is skipped
            ////////////////////////////////////////////////////
            let nativeValue
            switch iszero(token)
            case 0 {
                mstore(0x0, token)
                mstore(0x20, CALL_MANAGEMENT_APPROVALS)
                mstore(0x20, keccak256(0x0, 0x40))
                mstore(0x0, target)
                let key := keccak256(0x0, 0x40)
                // check if already approved
                if iszero(sload(key)) {
                    ////////////////////////////////////////////////////
                    // Approve, at this point it is clear that the target
                    // is whitelisted
                    ////////////////////////////////////////////////////
                    // selector for approve(address,uint256)
                    mstore(ptr, ERC20_APPROVE)
                    mstore(add(ptr, 0x04), target)
                    mstore(add(ptr, 0x24), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

                    if iszero(call(gas(), token, 0x0, ptr, 0x44, ptr, 32)) {
                        revert(0x0, 0x0)
                    }
                    sstore(key, 1)
                }
                nativeValue := 0
            }
            default {
                nativeValue := amount
            }
            // increment offset to calldata start
            currentOffset := add(56, currentOffset)
            // copy calldata
            calldatacopy(ptr, currentOffset, dataLength)
            if iszero(
                call(
                    gas(),
                    target,
                    nativeValue,
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
