// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Slots} from "../../shared/storage/Slots.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

/**
 * @title Universal aggregator contract.
 *        Allows spot and margin swap aggregation
 *        Efficient baching through compact calldata usage.
 * @author 1delta Labs AG
 */
contract AaveV2FlashLoans is Slots, ERC20Selectors, Masks, DeltaErrors {
    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | asset                           |
     * | 20     | 20             | pool                            | <-- we allow ANY aave v2 style pool here
     * | 40     | 14             | amount                          |
     * | 54     | 2              | paramsLength                    |
     * | 56     | paramsLength   | params                          |
     */
    function aaveV2FlashLoan(uint256 currentOffset, address callerAddress, uint256 poolId) internal returns (uint256) {
        assembly {
            // get token to loan
            let token := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            let pool := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            // second calldata slice including amount annd params length
            let slice := calldataload(currentOffset)
            let amount := shr(144, slice) // shr will already mask uint112 here
            // length of params
            let calldataLength := and(UINT16_MASK, shr(128, slice))

            currentOffset := add(currentOffset, 16)

            // call flash loan
            let ptr := mload(0x40)

            /**
             * Approve Aave V2 pool, they pull funds from the caller
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

            // flashLoan(...) (See Aave V2 ILendingPool)
            mstore(ptr, 0xab9c4b5d00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address()) // receiver is this address
            mstore(add(ptr, 36), 0x0e0) // offset assets
            mstore(add(ptr, 68), 0x120) // offset amounts
            mstore(add(ptr, 100), 0x160) // offset modes
            mstore(add(ptr, 132), 0) // onBefhalfOf = 0
            mstore(add(ptr, 164), 0x1a0) // offset calldata
            mstore(add(ptr, 196), 0) // referral code = 0
            mstore(add(ptr, 228), 1) // length assets
            mstore(add(ptr, 260), token) // assets[0]
            mstore(add(ptr, 292), 1) // length amounts
            mstore(add(ptr, 324), amount) // amounts[0]
            mstore(add(ptr, 356), 1) // length modes
            mstore(add(ptr, 388), 0) // mode = 0
            ////////////////////////////////////////////////////
            // We attach [souceId | caller] as first 21 bytes
            // to the params
            ////////////////////////////////////////////////////
            mstore(add(ptr, 420), add(21, calldataLength)) // length calldata (plus 1 + address)
            mstore8(add(ptr, 452), poolId) // source id <- this is crucial as we need this to validte the callback
            // caller at the beginning
            mstore(add(ptr, 453), shl(96, callerAddress))

            // copy the calldataslice for the params
            calldatacopy(
                add(ptr, 473), // next slot
                currentOffset, // offset starts at 37, already incremented
                calldataLength // copy given length
            ) // calldata
            if iszero(
                call(
                    gas(),
                    pool,
                    0x0,
                    ptr,
                    add(calldataLength, 473), // = 14 * 32 + 4 + 20 (caller)
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
