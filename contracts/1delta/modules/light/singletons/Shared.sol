// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Masks} from "../../shared/masks/Masks.sol";
import {Gen2025ActionIds} from "../enums/DeltaEnums.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

abstract contract SharedSingletonActions is Masks {
    // Uni V4 & Balancer V3 unlock
    bytes32 private constant UNLOCK = 0x48c8949100000000000000000000000000000000000000000000000000000000;
    // Hard-coded selector used for Balancer V3 callback
    /// @notice selector by bytes4(keccak256("balancerUnlockCallback(bytes)"))
    bytes32 private constant CB_SELECTOR = 0x480cf7ef00000000000000000000000000000000000000000000000000000000;

    /**
     * Here we need to add a selector deterministically as this function is Identical for B3 and U4
     */
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

            /**
             * We populate
             * manager.unlock(
             *  abi.encodeWithSelector(
             *      CB_SELECTOR,
             *      poolId, <- this is for validation purposes, we only allow correct uni V4s or balancer V3s
             *      data
             *   )
             * )
             */
            mstore(ptr, UNLOCK)
            mstore(add(ptr, 4), 0x20) // offset
            mstore(add(ptr, 36), add(dataLength, 89)) // selector, address, poolId, offset, length 4+32+32+20+1
            mstore(add(ptr, 68), CB_SELECTOR)
            mstore(add(ptr, 72), 0x20) // offset as for cb selector
            mstore(add(ptr, 104), add(dataLength, 21)) // length for within cb selector
            mstore8(add(ptr, 136), poolId)
            mstore(add(ptr, 137), shl(96, callerAddress))
            currentOffset := add(currentOffset, 21)
            // copy calldata
            calldatacopy(add(ptr, 157), currentOffset, dataLength)
            if iszero(
                call(
                    gas(),
                    manager,
                    0x0,
                    ptr, //
                    add(dataLength, 157), // selector, 2x offset, 2x length, data * address + uint8
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
