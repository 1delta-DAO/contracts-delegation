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
contract AaveV3FlashLoans is Slots, ERC20Selectors, Masks, DeltaErrors {
    // Aave V3 style lender pool addresses
    address private constant AAVE_V3 = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    address private constant AVALON = 0x6374a1F384737bcCCcD8fAE13064C18F7C8392e5;

    address private constant ZEROLEND = 0x766f21277087E18967c1b10bF602d8Fe56d0c671;

    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | asset                           |
     * | 20     | 20             | pool                            | <-- we allow ANY aave v2 style pool here
     * | 40     | 14             | amount                          |
     * | 54     | 2              | paramsLength                    |
     * | 56     | paramsLength   | params                          |
     */
    function aaveV3FlashLoan(uint256 currentOffset, address callerAddress, uint256 poolId) internal returns (uint256) {
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

            let ptr := mload(0x40)

            /**
             * Approve Aave V3 pool, they pull funds from the caller
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

            // flashLoanSimple(...)
            mstore(ptr, 0x42b0b77c00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address())
            mstore(add(ptr, 36), token) // asset
            mstore(add(ptr, 68), amount) // amount
            mstore(add(ptr, 100), 0xa0) // offset calldata
            mstore(add(ptr, 132), 0) // refCode
            mstore(add(ptr, 164), add(21, calldataLength)) // length calldata
            mstore8(add(ptr, 196), poolId) // source id
            // caller at the beginning
            mstore(add(ptr, 197), shl(96, callerAddress))
            calldatacopy(add(ptr, 217), currentOffset, calldataLength) // calldata
            if iszero(
                call(
                    gas(),
                    pool,
                    0x0,
                    ptr,
                    add(calldataLength, 228), // = 7 * 32 + 4
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
     * @dev Aave V3 style flash loan callback
     */
    function executeOperation(
        address,
        uint256 flashAmount,
        uint256 fee,
        address initiator,
        bytes calldata params // user params
    ) external returns (bool) {
        address origCaller;
        uint256 calldataLength;
        uint256 payback;
        assembly {
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
            let firstWord := calldataload(196)
            // needs no uint8 masking as we shift 248 bits
            let source := shr(248, firstWord)

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the `initiator` paramter the caller of `flashLoan`
            switch source
            case 0 {
                if xor(caller(), AAVE_V3) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }
            }
            case 1 {
                if xor(caller(), AVALON) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }
            }
            case 2 {
                if xor(caller(), ZEROLEND) {
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
            // an Aave V3 type lending pool
            if xor(address(), initiator) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // compute amount to be paid back
            payback := add(flashAmount, fee)
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the `origCaller`
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := and(ADDRESS_MASK, shr(88, firstWord))
            // shift / slice params
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(
            origCaller,
            payback,
            flashAmount,
            217, // 196 +21 as constant offset
            calldataLength
        );
        return true;
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
