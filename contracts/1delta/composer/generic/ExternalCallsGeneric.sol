// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";

// solhint-disable max-line-length

/**
 * @notice External call on any target - prevents `transferFrom` selector
 */
abstract contract ExternalCallsGeneric is BaseUtils {
    /// @dev mask for selector in calldata
    bytes32 private constant SELECTOR_MASK = 0xffffffff00000000000000000000000000000000000000000000000000000000;

    // Forbidden()
    bytes4 private constant FORBIDDEN = 0xee90c468;

    function _callExternal(uint256 currentOffset) internal returns (uint256) {
        /*
         * | Offset | Length (bytes) | Description          |
         * |--------|----------------|----------------------|
         * | 0      | 20             | target               |
         * | 20     | 16             | nativeValue          |
         * | 36     | 2              | calldataLength:  cl  |
         * | 38     | cl             | calldata             |
         */
        assembly {
            // get first three addresses
            let target := shr(96, calldataload(currentOffset))

            // prevent calls to permit2
            if eq(target, 0x000000000022D473030F116dDEE9F6B43aC78BA3) {
                mstore(0x0, FORBIDDEN)
                revert(0x0, 0x4)
            }

            currentOffset := add(20, currentOffset)

            let callValue := shr(128, calldataload(currentOffset))
            currentOffset := add(16, currentOffset)

            let dataLength := shr(240, calldataload(currentOffset))
            currentOffset := add(2, currentOffset)

            switch and(NATIVE_FLAG, callValue)
            case 0 { callValue := and(callValue, UINT112_MASK) }
            case 1 { callValue := selfbalance() }

            // free memo ptr for populating the tx
            let ptr := mload(0x40)

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
                    dataLength,
                    // the length must be correct or the call will fail
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
         * | 34     | 2              | calldataLength:  cl  |
         * | 36     | cl             | calldata             |
         * | 36+cl  | 1              | catchHandling        | <- 0: revert, 1:
         * | 37+cl  | 2              | catchDataLength: dl  |
         * | 39+cl  | dl             | catchData            |
         */
        bool success;
        uint256 catchHandling;
        uint256 catchCalldataLength;
        assembly {
            let target := shr(96, calldataload(currentOffset))

            // prevent calls to permit2
            if eq(target, 0x000000000022D473030F116dDEE9F6B43aC78BA3) {
                mstore(0x0, FORBIDDEN)
                revert(0x0, 0x4)
            }

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

            // extract the selector from the calldata
            // and check if it is `transferFrom`
            if eq(and(SELECTOR_MASK, calldataload(currentOffset)), ERC20_TRANSFER_FROM) {
                mstore(0x0, FORBIDDEN)
                revert(0x0, 0x4)
            }

            // copy calldata
            calldatacopy(ptr, currentOffset, dataLength)
            success :=
                call(
                    gas(),
                    target,
                    callValue,
                    ptr, //
                    dataLength,
                    // the length must be correct or the call will fail
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
