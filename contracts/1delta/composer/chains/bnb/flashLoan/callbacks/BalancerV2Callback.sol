// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Slots} from "../../../../slots/Slots.sol";
import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * Flash loaning through BalancerV2
 */
contract BalancerV2FlashLoanCallback is Slots, Masks, DeltaErrors {
    // Balancer V2 vaults
    address private constant SWAAP = 0x03C01Acae3D0173a93d819efDc832C7C4F153B06;

    /**
     * @dev Balancer flash loan call
     * Gated via flash loan gateway flag to prevent calls from sources other than this contract
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    )
        external
    {
        address origCaller;
        uint256 calldataOffset;
        uint256 calldataLength;
        assembly {
            calldataOffset := params.offset
            calldataLength := params.length

            // validate caller
            // - extract id from params
            let firstWord := calldataload(calldataOffset)

            switch and(UINT8_MASK, shr(88, firstWord))
            case 2 {
                if xor(caller(), SWAAP) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // check that the entry flag is
            if iszero(eq(2, sload(FLASH_LOAN_GATEWAY_SLOT))) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }

            // Close the gateway slot afterwards!
            // This prevents a double_entry though 2 acccepted
            // Balancer V2 forks where one would use the first
            // through this contract, pass the validation, then use the second to
            // reenter from an attacker contract - the gateway would then be open still
            // and the attacker could execute an arbitrary delta compose
            // locking the callback again here prevents this scenario
            sstore(FLASH_LOAN_GATEWAY_SLOT, 1)
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the origCaller
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, firstWord)
            // shift / slice params
            calldataOffset := add(calldataOffset, 21)
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, calldataOffset, calldataLength);
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
