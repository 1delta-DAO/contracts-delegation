// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Slots} from "../../shared/storage/Slots.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

/**
 * @title Morpho flash loans
 * @author 1delta Labs AG
 */
contract MorphoFlashLoans is Slots, ERC20Selectors, Masks, DeltaErrors {
    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | asset                           |
     * | 20     | 20             | pool                            | <-- we allow ANY morpho style pool here
     * | 20     | 14             | amount                          |
     * | 34     | 2              | paramsLength                    |
     * | 36     | paramsLength   | params                          |
     */
    function morphoFlashLoan(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let slice := calldataload(currentOffset)
            // get token to loan
            let token := and(ADDRESS_MASK, shr(96, slice))
            currentOffset := add(currentOffset, 20)
            let pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            // second calldata slice including amount annd params length
            slice := calldataload(currentOffset)
            let amount := shr(144, slice) // shr will already mask uint112 here
            // length of params
            let calldataLength := and(UINT16_MASK, shr(128, slice))
            // skip uint112 and uint16
            currentOffset := add(currentOffset, 16)

            // morpho should be the primary choice
            let ptr := mload(0x40)

            /**
             * Approve MB beforehand for the flash amount
             * Similar to Aave V3, they pull funds from the caller
             */
            mstore(0x0, token)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, pool)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), pool)
                mstore(add(ptr, 0x24), MAX_UINT256)

                if iszero(call(gas(), token, 0x0, ptr, 0x44, ptr, 32)) {
                    revert(0x0, 0x0)
                }
                sstore(key, 1)
            }

            /** Prepare call */

            // flashLoan(...)
            mstore(ptr, 0xe0232b4200000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), token)
            mstore(add(ptr, 36), amount)
            mstore(add(ptr, 68), 0x60) // offset
            mstore(add(ptr, 100), add(20, calldataLength)) // data length
            mstore(add(ptr, 132), shl(96, callerAddress)) // caller
            calldatacopy(add(ptr, 152), currentOffset, calldataLength) // calldata
            if iszero(
                call(
                    gas(),
                    pool,
                    0x0,
                    ptr,
                    add(calldataLength, 152), // = 10 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
            // increment offset
            currentOffset := add(currentOffset, calldataLength)
        }
        return currentOffset;
    }
}
