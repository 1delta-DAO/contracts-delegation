// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Slots} from "../../shared/storage/Slots.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

/**
 * Flash loaning through BalancerV2
 */
contract BalancerV2FlashLoans is Slots, ERC20Selectors, Masks, DeltaErrors {
    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | asset                           |
     * | 20     | 20             | pool                            | <-- we allow ANY balancer style pool here
     * | 40     | 14             | amount                          |
     * | 54     | 2              | paramsLength                    |
     * | 56     | paramsLength   | params                          |
     */
    function balancerV2FlashLoan(uint256 currentOffset, address callerAddress, uint256 poolId) internal returns (uint256) {
        assembly {
            // get token to loan
            let token := shr(96, calldataload(currentOffset))

            // target to call
            let pool := shr(96, calldataload(add(currentOffset, 20)))

            // second calldata slice including amount annd params length
            let slice := calldataload(add(currentOffset, 40))
            let amount := shr(144, slice) // shr will already mask uint112 here
            // length of params
            let calldataLength := and(UINT16_MASK, shr(128, slice))

            // skip addresses and amount
            currentOffset := add(currentOffset, 56)
            // balancer should be the secondary choice
            let ptr := mload(0x40)
            // flashLoan(...)
            mstore(ptr, 0x5c38449e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address())
            mstore(add(ptr, 36), 0x80) // offset assets
            mstore(add(ptr, 68), 0xc0) // offset amounts
            mstore(add(ptr, 100), 0x100) // offset calldata
            mstore(add(ptr, 132), 1) // length assets
            mstore(add(ptr, 164), token) // asset
            mstore(add(ptr, 196), 1) // length amounts
            mstore(add(ptr, 228), amount) // amount
            mstore(add(ptr, 260), add(21, calldataLength)) // length calldata
            mstore8(add(ptr, 292), poolId) // source id
            // caller at the beginning
            mstore(add(ptr, 293), shl(96, callerAddress))
            calldatacopy(add(ptr, 313), currentOffset, calldataLength) // calldata
            // set entry flag
            sstore(FLASH_LOAN_GATEWAY_SLOT, 2)
            if iszero(
                call(
                    gas(),
                    pool,
                    0x0,
                    ptr,
                    add(calldataLength, 345), // = 10 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
            // unset entry flasg
            sstore(FLASH_LOAN_GATEWAY_SLOT, 1)
            // increment offset
            currentOffset := add(currentOffset, calldataLength)
        }
        return currentOffset;
    }
}
