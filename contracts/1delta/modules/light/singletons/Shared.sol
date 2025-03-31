// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Masks} from "../../shared/masks/Masks.sol";
import {Gen2025ActionIds} from "../enums/DeltaEnums.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

abstract contract SharedSingletonActions is Masks {
    // Uni V4 selectors needed for executing a flash loan
    bytes32 private constant UNLOCK = 0x48c8949100000000000000000000000000000000000000000000000000000000;

    constructor() {}

    function _singletonUnlock(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        /*
         * | Offset | Length (bytes) | Description     |
         * |--------|----------------|-----------------|
         * | 0      | 20             | manager         |
         * | 20     | 1              | poolId          |
         * | 21     | 2              | length          |
         * | 23     | length         | data            |
         */
        assembly {
            let manager := calldataload(currentOffset)
            let dataLength := and(UINT16_MASK, shr(72, manager))
            let poolId := and(UINT8_MASK, shr(88, manager))
            manager := shr(96, manager)

            // free memo ptr for populating the tx
            let ptr := mload(0x40)

            mstore(ptr, UNLOCK)
            mstore(add(ptr, 4), 0x20) // offset
            mstore(add(ptr, 36), add(dataLength, 21))
            mstore8(add(ptr, 68), poolId)
            mstore(add(ptr, 69), shl(96, callerAddress))
            currentOffset := add(currentOffset, 21)
            // copy calldata
            calldatacopy(add(ptr, 89), currentOffset, dataLength)
            if iszero(
                call(
                    gas(),
                    manager,
                    0x0,
                    ptr, //
                    add(dataLength, 89), // selector, offset, length, data
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // increment offset by data length, manager, poolId
            currentOffset := add(add(currentOffset, 2), dataLength)
        }
        return currentOffset;
    }
}
