// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {Masks} from "../../../../shared/masks/Masks.sol";

/**
 * @title Phiat flash loan executor
 * @author 1delta Labs AG
 */
contract PhiatFlashLoans is Masks {
    /**
     * @notice Executes Phiat flash loan
     * @dev Phiat uses an Aave-V2-style pool but with a slimmer flashLoan signature
     *      (no modes[] / onBehalfOf): flashLoan(address,address[],uint256[],bytes,uint16)
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | asset                           |
     * | 20     | 20             | pool                            |
     * | 40     | 16             | amount                          |
     * | 56     | 2              | paramsLength                    |
     * | 58     | paramsLength   | params                          |
     */
    function phiatFlashLoan(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // get token to loan
            let token := shr(96, calldataload(currentOffset))

            // target to call
            let pool := shr(96, calldataload(add(currentOffset, 20)))

            // second calldata slice including amount and params length
            let slice := calldataload(add(currentOffset, 40))
            let amount := shr(128, slice)
            // length of params
            let calldataLength := and(UINT16_MASK, shr(112, slice))

            // skip addresses and amount
            currentOffset := add(currentOffset, 58)

            // call flash loan
            let ptr := mload(0x40)
            // flashLoan(address,address[],uint256[],bytes,uint16)
            mstore(ptr, 0xe7e7d62a00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address()) // receiver is this address
            mstore(add(ptr, 36), 0x0a0) // offset assets
            mstore(add(ptr, 68), 0x0e0) // offset amounts
            mstore(add(ptr, 100), 0x120) // offset calldata
            mstore(add(ptr, 132), 0) // referral code = 0
            mstore(add(ptr, 164), 1) // length assets
            mstore(add(ptr, 196), token) // assets[0]
            mstore(add(ptr, 228), 1) // length amounts
            mstore(add(ptr, 260), amount) // amounts[0]
            ////////////////////////////////////////////////////
            // We attach [caller] as first 20 bytes
            ////////////////////////////////////////////////////
            mstore(add(ptr, 292), add(20, calldataLength)) // length calldata (plus address)
            // caller at the beginning
            mstore(add(ptr, 324), shl(96, callerAddress))

            // copy the calldataslice for the params
            calldatacopy(
                add(ptr, 344), // next slot (after 20-byte caller prefix)
                currentOffset, // offset already incremented past header
                calldataLength // copy given length
            ) // calldata
            if iszero(
                call(
                    gas(),
                    pool,
                    0x0,
                    ptr,
                    add(calldataLength, 344), // = 10 * 32 + 4 + 20 (caller)
                    0x0,
                    0x0 //
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }

            // increment offset
            currentOffset := add(currentOffset, calldataLength)
        }
        return currentOffset;
    }
}
