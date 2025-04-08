// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Slots} from "../../../shared/storage/Slots.sol";
import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";

/**
 * Flash loaning through BalancerV2
 */
contract BalancerV2FlashLoanCallback is Slots, Masks, DeltaErrors {
    // Balancer V2 vault
    address private constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    /**
     * @dev Balancer flash loan call
     * Gated via flash loan gateway flag to prevent calls from sources other than this contract
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external {
        address origCaller;
        uint256 calldataOffset;
        uint256 calldataLength;
        assembly {
            calldataOffset := params.offset
            calldataLength := params.length

            // validate caller
            // - extract id from params
            let firstWord := calldataload(calldataOffset)
            let source := and(UINT8_MASK, shr(88, firstWord))

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the `initiator` paramter the caller of `flashLoan`
            switch source
            case 0 {
                if xor(caller(), BALANCER_V2_VAULT) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            // We revert on any other id
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // check that the entry flag is
            if iszero(eq(2, sload(FLASH_LOAN_GATEWAY_SLOT))) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the `origCaller`
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, firstWord)
            // shift / slice params
            calldataOffset := add(calldataOffset, 21)
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, 0, 0, calldataOffset, calldataLength);
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
