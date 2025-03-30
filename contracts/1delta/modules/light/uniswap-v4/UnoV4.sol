// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";
import {UniswapV4ActionIds} from "../enums/DeltaEnums.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Everything Uniswap V4
 */
abstract contract UniswapV4 is Masks, DeltaErrors {
    // Uni V4 selectors needed for executing a flash loan
    bytes32 private constant UNLOCK = 0x48c8949100000000000000000000000000000000000000000000000000000000;
    bytes32 private constant TAKE = 0x0b0d9c0900000000000000000000000000000000000000000000000000000000;
    bytes32 private constant SETTLE = 0x11da60b400000000000000000000000000000000000000000000000000000000;
    bytes32 private constant SYNC = 0xa584119400000000000000000000000000000000000000000000000000000000;

    constructor() {}

    function _uniV4Ops(
        uint256 currentOffset,
        address callerAddress,
        uint256 paramPull,
        uint256 paramPush //
    ) internal returns (uint256) {
        uint256 transferOperation;
        assembly {
            let firstSlice := calldataload(currentOffset)
            transferOperation := shr(248, firstSlice)
            currentOffset := add(currentOffset, 1)
        }
        if (transferOperation == UniswapV4ActionIds.UNLOCK) {
            return _unoV4Unlock(currentOffset, callerAddress);
        } else if (transferOperation == UniswapV4ActionIds.TAKE) {
            return _unoV4Take(currentOffset, paramPull);
        } else if (transferOperation == UniswapV4ActionIds.SYNC) {
            return _unoV4Sync(currentOffset);
        } else if (transferOperation == UniswapV4ActionIds.SETTLE) {
            return _unoV4Settle(currentOffset, paramPush);
        } else {
            _invalidOperation();
        }
    }

    function _unoV4Unlock(uint256 currentOffset, address callerAddress) internal returns (uint256) {
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

    function _unoV4Take(uint256 currentOffset, uint256 amountOverride) internal returns (uint256) {
        /*
         * | Offset | Length (bytes) | Description         |
         * |--------|----------------|---------------------|
         * | 0      | 20             | manager             |
         * | 20     | 20             | asset               |
         * | 40     | 20             | receiver            |
         * | 60     | 16             | amount              |
         */
        assembly {
            let manager := shr(96, calldataload(currentOffset))
            currentOffset := add(20, currentOffset)
            let asset := shr(96, calldataload(currentOffset))
            currentOffset := add(20, currentOffset)
            let receiver := shr(96, calldataload(currentOffset))
            currentOffset := add(20, currentOffset)
            let amount := shr(128, calldataload(currentOffset))
            if and(_PRE_PARAM, amount) {
                amount := amountOverride
            }
            // free memo ptr for populating the tx
            let ptr := mload(0x40)

            // increment offset to calldata start
            currentOffset := add(22, currentOffset)

            mstore(ptr, TAKE)
            mstore(add(ptr, 4), asset) // offset
            mstore(add(ptr, 36), receiver)
            mstore(add(ptr, 68), amount)

            if iszero(
                call(
                    gas(),
                    manager,
                    0x0,
                    ptr, //
                    100, // selector, offset, length, data
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // increment offset by amount length
            currentOffset := add(currentOffset, 16)
        }
        return currentOffset;
    }

    function _unoV4Sync(uint256 currentOffset) internal returns (uint256) {
        /*
         * | Offset | Length (bytes) | Description   |
         * |--------|----------------|---------------|
         * | 0      | 20             | manager       |
         * | 20     | 20             | asset         |
         */
        assembly {
            let manager := shr(96, calldataload(currentOffset))
            currentOffset := add(20, currentOffset)
            let asset := shr(96, calldataload(currentOffset))
            currentOffset := add(20, currentOffset)

            // increment offset to calldata start
            currentOffset := add(22, currentOffset)

            mstore(0, SYNC)
            mstore(4, asset) // offset

            if iszero(
                call(
                    gas(),
                    manager,
                    0x0,
                    0, //
                    36, // selector, offset, length, data
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        return currentOffset;
    }

    function _unoV4Settle(uint256 currentOffset, uint256 amountOverride) internal returns (uint256) {
        /*
         * | Offset | Length (bytes) | Description       |
         * |--------|----------------|-------------------|
         * | 0      | 20             | manager           |
         * | 20     | 16             | nativeAmount      |
         */
        assembly {
            let manager := shr(96, calldataload(currentOffset))
            currentOffset := add(20, currentOffset)
            let amount := shr(128, calldataload(currentOffset))
            if and(_PRE_PARAM, amount) {
                amount := amountOverride
            }
            currentOffset := add(16, currentOffset)

            mstore(0, SETTLE)

            if iszero(
                call(
                    gas(),
                    manager,
                    amount,
                    0, //
                    4, // selector, offset, length, data
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        return currentOffset;
    }
}
