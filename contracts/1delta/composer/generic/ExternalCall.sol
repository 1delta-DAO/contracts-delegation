// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";

// solhint-disable max-line-length

/**
 * @notice External call on call forwarder which can safely execute any calls
 * without comprimising this contract
 */
abstract contract ExternalCall is BaseUtils {
    /// @notice selector for deltaForwardCompose(bytes)
    bytes32 private constant DELTA_FORWARD_COMPOSE = 0x6a0c90ff00000000000000000000000000000000000000000000000000000000;

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

            // increment offset to calldata start
            currentOffset := add(16, currentOffset)

            mstore(ptr, DELTA_FORWARD_COMPOSE)
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

    function _tryCallExternal(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        /*
         * | Offset | Length (bytes) | Description          |
         * |--------|----------------|----------------------|
         * | 0      | 20             | target               |
         * | 20     | 14             | nativeValue          |
         * | 41     | 2              | calldataLength:  cl  |
         * | 42     | cl             | calldata             |
         * | 42+cl  | 1              | catchHandling        | <- 0: revert, 1:
         * | 43+cl  | 2              | catchDataLength: dl  |
         * | 45+cl  | dl             | catchData            |
         */
        bool success;
        uint256 catchHandling;
        uint256 catchCalldataLength;
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

            // increment offset to calldata start
            currentOffset := add(16, currentOffset)

            mstore(ptr, DELTA_FORWARD_COMPOSE)
            mstore(add(ptr, 0x4), 0x20) // offset
            mstore(add(ptr, 0x24), dataLength) // length

            // copy calldata
            calldatacopy(add(ptr, 0x44), currentOffset, dataLength)
            success :=
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

            // increment offset by data length
            currentOffset := add(currentOffset, dataLength)

            let nexstSlice := calldataload(currentOffset)
            // top byte of next slice
            catchHandling := shr(248, nexstSlice)
            // case: 0 revert if not successful
            if iszero(catchHandling) {
                if iszero(success) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }

            catchCalldataLength := and(UINT16_MASK, shr(236, nexstSlice))
            currentOffset := add(currentOffset, 3)
        }

        // execution logic on failute
        if (!success) {
            // Catch and run fallback
            // execute further calldata if provided
            if (catchCalldataLength > 0) {
                // if calldata is provided, compose the remaining data
                _deltaComposeInternal(callerAddress, currentOffset, catchCalldataLength);
            }
            // case 1 - exit funciton execution here
            if (catchHandling == 1) {
                assembly {
                    return(0, 0)
                }
            }
        }
        // increment offset by additional data length
        assembly {
            currentOffset := add(currentOffset, catchCalldataLength)
        }
        return currentOffset;
    }

    function _deltaComposeInternal(
        address callerAddress,
        uint256 currentOffset,
        uint256 calldataLength //
    )
        internal
        virtual;
}
