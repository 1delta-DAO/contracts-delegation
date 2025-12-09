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
     * @notice Handles Balancer V2 flash loan callback
     * @dev Gated via flash loan gateway flag to prevent calls from sources other than this contract
     * @param params Calldata containing the original caller and compose operations
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | origCaller                   |
     * | 20     | 1              | poolId                       |
     * | 21     | Variable       | composeOperations            |
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

            // validate caller via provided poolId
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
            // check that the flag is set correctly
            if iszero(eq(1, tload(FLASH_LOAN_GATEWAY_SLOT))) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }

            // Close the gateway slot afterwards!
            // This prevents a double entry though 2 acccepted
            // Balancer V2 forks where one would use the first
            // through this contract, pass the validation, then use the second to
            // reenter from an attacker contract - the gateway would then be open
            // and the attacker could execute an arbitrary delta compose.
            // Locking the callback again here (instead of after the flashLoan call)
            // prevents this scenario!
            tstore(FLASH_LOAN_GATEWAY_SLOT, 0)
            // Get the original caller from the beginning of the calldata
            // From here on we have validated that the origCaller
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, firstWord)
            // shift / slice params
            calldataOffset := add(calldataOffset, 21)
            calldataLength := sub(params.length, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, calldataOffset, calldataLength);
    }

    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for flash loan callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
