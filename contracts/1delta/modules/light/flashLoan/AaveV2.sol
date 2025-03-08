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
    // Aave v2s
    address private constant GRANARY = 0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3;

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

            // increment offset by the preceding bytes length
            currentOffset := add(currentOffset, 37)
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


    /**
     * @dev Aave V2 style flash loan callback
     */
    function executeOperation(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata, // we assume that the data is known to the caller in advance
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        address origCaller;
        uint256 calldataOffset;
        uint256 calldataLength;
        assembly {
            calldataOffset := params.offset
            calldataLength := params.length
            // we expect at least an address
            // and a sourceId (uint8)
            // invalid params will lead to errors in the
            // compose at the bottom
            if lt(calldataLength, 21) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // validate caller
            // - extract id from params
            let firstWord := calldataload(calldataOffset)
            // needs no uint8 masking as we shift 248 bits
            let source := shr(248, firstWord)

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the `initiator` paramter the caller of `flashLoan`
            switch source
            case 240 {
                if xor(caller(), GRANARY) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }
            }
            // We revert on any other id
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // We require to self-initiate
            // this prevents caller impersonation,
            // but ONLY if the caller address is
            // an Aave V2 type lending pool
            if xor(address(), initiator) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the `origCaller`
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := and(ADDRESS_MASK, shr(88, firstWord))
            // shift / slice params
            calldataOffset := add(calldataOffset, 21)
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, 0, 0, calldataOffset, calldataLength);
        return true;
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
