// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

// solhint-disable max-line-length

/**
 * @notice External call on call forwarder which can safely execute any calls
 * without comprimising this contract
 */
abstract contract ExternalCall is Masks, DeltaErrors {
    /// @notice selector for deltaComposeLevel2(bytes)
    bytes32 private constant COMPOSER_LEVEL2_COMPOSE = 0xfd2eb88300000000000000000000000000000000000000000000000000000000;

    /**
     * This is not a real external call, this one has a pre-determined selector
     * that prevents collision with any calls that can be made in this contract
     * This prevents unauthorized calls that would pull funds from other users
     *
     * On top of that, this makes the contract arbitrarily extensible.
     */
    function _callExternal(uint256 currentOffset) internal returns (uint256) {
        /*
         * | Offset | Length (bytes) | Description          |
         * |--------|----------------|----------------------|
         * | 0      | 20             | target               |
         * | 20     | 14             | nativeValue          |
         * | 41     | 2              | calldataLength       |
         * | 42     | calldataLength | calldata             |
         */
        assembly {
            let target := shr(96, calldataload(currentOffset))
            currentOffset := add(20, currentOffset)
            // get msg.value for call
            let callValue := calldataload(currentOffset)
            let dataLength := and(UINT16_MASK, shr(128, callValue))
            callValue := shr(144, callValue) // shr will already mask correctly

            if iszero(callValue) { callValue := selfbalance() }

            // free memo ptr for populating the tx
            let ptr := mload(0x40)

            ////////////////////////////////////////////////////
            // If the token is zero, we assume that it is a native
            // transfer / swap and the approval check is skipped
            ////////////////////////////////////////////////////

            // increment offset to calldata start
            currentOffset := add(16, currentOffset)

            mstore(ptr, COMPOSER_LEVEL2_COMPOSE)
            mstore(add(ptr, 0x4), 0x20) // offset
            mstore(add(ptr, 0x24), dataLength) // length

            // copy calldata
            calldatacopy(add(ptr, 0x44), currentOffset, dataLength)
            if iszero(
                call(
                    gas(),
                    target,
                    callValue,
                    ptr, //
                    add(0x44, dataLength),
                    //selector plus 0x44 (selector, offset, length)
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
