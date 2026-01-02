// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";

// solhint-disable max-line-length

/**
 * @notice External call on any target - prevents `transferFrom` selector & call on Permit2
 */
abstract contract ExternalCallsGeneric is BaseUtils {
    /// @dev mask for selector in calldata
    bytes32 private constant SELECTOR_MASK = 0xffffffff00000000000000000000000000000000000000000000000000000000;

    // Forbidden()
    bytes4 private constant FORBIDDEN = 0xee90c468;

    /**
     * @notice Executes an external call on any target
     * @dev Prevents `transferFrom` selector and calls on Permit2
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | target               |
     * | 20     | 16             | nativeValue          |
     * | 36     | 2              | calldataLength:  cl  |
     * | 38     | cl             | calldata             |
     */
    function _callExternal(uint256 currentOffset) internal returns (uint256) {
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
            default { callValue := selfbalance() }

            // free memo ptr for populating the tx
            let ptr := mload(0x40)

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

    /**
     * @notice Executes an external call with error handling
     * @dev Prevents `transferFrom` selector and calls on Permit2. Supports catch blocks for error handling.
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | target               |
     * | 20     | 16             | nativeValue          |
     * | 36     | 2              | calldataLength:  cl  |
     * | 38     | cl             | calldata             |
     * | 38+cl  | 1              | catchHandling        | <- 0: revert; 1: exit in catch if revert; else continue after catch
     * | 39+cl  | 2              | catchDataLength: dl  |
     * | 41+cl  | dl             | catchData            |
     */
    function _tryCallExternal(uint256 currentOffset, address callerAddress) internal returns (uint256) {
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

            let callValue := shr(128, calldataload(currentOffset))
            currentOffset := add(16, currentOffset)

            let dataLength := shr(240, calldataload(currentOffset))
            currentOffset := add(2, currentOffset)

            switch and(NATIVE_FLAG, callValue)
            case 0 { callValue := and(callValue, UINT112_MASK) }
            default { callValue := selfbalance() }

            // free memo ptr for populating the tx
            let ptr := mload(0x40)

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
            if and(iszero(catchHandling), iszero(success)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            catchCalldataLength := and(UINT16_MASK, shr(232, nexstSlice))
            currentOffset := add(currentOffset, 3)
        }

        // execution logic on failute
        if (!success) {
            // Catch and run fallback
            // execute further calldata if provided
            if (catchCalldataLength > 0) {
                // Calculate the absolute end position for the catch data (last param of the _deltaComposeInternal)
                uint256 catchMaxIndex = currentOffset + catchCalldataLength;
                _deltaComposeInternal(callerAddress, currentOffset, catchMaxIndex);
                // Update currentOffset to the end of catch data
                currentOffset = catchMaxIndex;
            }
            // case 1 - exit function execution here
            if (catchHandling == 1) {
                assembly {
                    return(0, 0)
                }
            }
        } else {
            // if the call was successful, skip the catch data
            assembly {
                currentOffset := add(currentOffset, catchCalldataLength)
            }
        }
        return currentOffset;
    }

    /**
     * @notice Executes an external call with token amount replacement
     * @dev Prevents `transferFrom` selector and calls on Permit2. Can replace token amounts in calldata.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                |
     * |--------|----------------|--------------------------------------------|
     * | 0      | 20             | target                                     |
     * | 20     | 16             | nativeValue                                |
     * | 36     | 20             | token (zero to skip replacement)           |
     * | 56     | 2              | replaceOffset (byte offset after selector) |
     * | 58     | 2              | calldataLength: cl                         |
     * | 60     | cl             | calldata                                   |
     */
    function _callExternalWithReplace(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let target := shr(96, calldataload(currentOffset))

            // prevent calls to permit2
            if eq(target, 0x000000000022D473030F116dDEE9F6B43aC78BA3) {
                mstore(0x0, FORBIDDEN)
                revert(0x0, 0x4)
            }

            currentOffset := add(20, currentOffset)

            let callValue := shr(128, calldataload(currentOffset))
            currentOffset := add(16, currentOffset)

            let token := calldataload(currentOffset)
            let replaceOffset := and(UINT16_MASK, shr(80, token))
            let dataLength := and(UINT16_MASK, shr(64, token))
            token := shr(96, token)

            currentOffset := add(24, currentOffset)

            // validate replaceOffset is within calldata bounds
            if gt(add(add(replaceOffset, 32), 4), dataLength) {
                mstore(0x0, REPLACE_OFFSET_OUT_OF_BOUNDS)
                revert(0x0, 0x4)
            }

            // handle nativeValue flag
            switch and(NATIVE_FLAG, callValue)
            case 0 { callValue := and(callValue, UINT112_MASK) }
            default { callValue := selfbalance() }

            let ptr := mload(0x40)

            calldatacopy(ptr, currentOffset, dataLength)

            // only replace if token is not zero
            if gt(token, 0) {
                // erc20 balance of this
                mstore(0x0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                pop(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20))

                // offset to replace amount (mload(0)) in calldata (4 bytes for function selector)
                mstore(add(add(ptr, 4), replaceOffset), mload(0x0))
            }

            // prevent transferFrom selector
            if eq(and(SELECTOR_MASK, mload(ptr)), ERC20_TRANSFER_FROM) {
                mstore(0x0, FORBIDDEN)
                revert(0x0, 0x4)
            }

            if iszero(call(gas(), target, callValue, ptr, dataLength, 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            currentOffset := add(currentOffset, dataLength)
        }
        return currentOffset;
    }

    /**
     * @notice Executes an external call with token amount replacement and error handling
     * @dev Prevents `transferFrom` selector and calls on Permit2. Can replace token amounts in calldata. Supports catch blocks.
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                |
     * |--------|----------------|--------------------------------------------|
     * | 0      | 20             | target                                     |
     * | 20     | 16             | nativeValue                                |
     * | 36     | 20             | token (zero to skip replacement)           |
     * | 56     | 2              | replaceOffset (byte offset after selector) |
     * | 58     | 2              | calldataLength: cl                         |
     * | 60     | 1              | catchHandling                              | <- 0: revert; 1: exit in catch if revert; else continue after catch
     * | 61     | 2              | catchDataLength: dl                        |
     * | 63     | cl             | calldata                                   |
     * | 63+cl  | dl             | catchData                                  |
     */
    function _tryCallExternalWithReplace(uint256 currentOffset, address callerAddress) internal returns (uint256) {
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

            let callValue := shr(128, calldataload(currentOffset))
            currentOffset := add(16, currentOffset)

            let token := calldataload(currentOffset)
            let replaceOffset := and(UINT16_MASK, shr(80, token))
            let dataLength := and(UINT16_MASK, shr(64, token))
            catchHandling := and(UINT8_MASK, shr(56, token))
            catchCalldataLength := and(UINT16_MASK, shr(40, token))

            token := shr(96, token)
            currentOffset := add(27, currentOffset)

            // validate replaceOffset is within calldata bounds
            if gt(add(add(replaceOffset, 32), 4), dataLength) {
                mstore(0x0, REPLACE_OFFSET_OUT_OF_BOUNDS)
                revert(0x0, 0x4)
            }

            // handle nativeValue flag
            switch and(NATIVE_FLAG, callValue)
            case 0 { callValue := and(callValue, UINT112_MASK) }
            default { callValue := selfbalance() }

            let ptr := mload(0x40)

            calldatacopy(ptr, currentOffset, dataLength)

            // only replace if token is not zero
            if gt(token, 0) {
                // erc20 balance of this
                mstore(0x0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                pop(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20))

                // offset to replace amount (mload(0)) in calldata (4 bytes for function selector)
                mstore(add(add(ptr, 4), replaceOffset), mload(0x0))
            }

            // prevent transferFrom selector
            if eq(and(SELECTOR_MASK, mload(ptr)), ERC20_TRANSFER_FROM) {
                mstore(0x0, FORBIDDEN)
                revert(0x0, 0x4)
            }

            success := call(gas(), target, callValue, ptr, dataLength, 0x0, 0x0)

            // case: 0 revert if not successful
            if and(iszero(catchHandling), iszero(success)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            // increment offset by data length to get to catchData
            currentOffset := add(currentOffset, dataLength)
        }

        // execution logic on failure
        if (!success) {
            // Catch and run fallback
            // execute further calldata if provided
            if (catchCalldataLength > 0) {
                // Calculate the absolute end position for the catch data (last param of the _deltaComposeInternal)
                uint256 catchMaxIndex = currentOffset + catchCalldataLength;
                _deltaComposeInternal(callerAddress, currentOffset, catchMaxIndex);
                // Update currentOffset to the end of catch data
                currentOffset = catchMaxIndex;
            }
            // case 1 - exit function execution here
            if (catchHandling == 1) {
                assembly {
                    return(0, 0)
                }
            }
        } else {
            // if the call was successful, skip the catch data
            assembly {
                currentOffset := add(currentOffset, catchCalldataLength)
            }
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
