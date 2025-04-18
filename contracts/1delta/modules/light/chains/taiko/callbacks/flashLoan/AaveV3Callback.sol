// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave v3 flash loan callback
 */
contract AaveV3FlashLoanCallback is Masks, DeltaErrors {
    // Aave V3 style lender pool addresses
    address private constant HANA = 0x4aB85Bf9EA548410023b25a13031E91B4c4f3b91;
    address private constant AVALON = 0xA7f1c55530B1651665C15d8104663B3f03E3386f;
    address private constant AVALON_SOLV_BTC = 0x9dd29AA2BD662E6b569524ba00C55be39e7B00fB;
    address private constant AVALON_USDA = 0xC1bFbF4E0AdCA79790bfa0A557E4080F05e2B438;

    /**
     * @dev Aave V3 style flash loan callback
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address initiator,
        bytes calldata params // user params
    )
        external
        returns (bool)
    {
        address origCaller;
        uint256 calldataLength;
        assembly {
            calldataLength := params.length

            // validate caller
            // - extract id from params
            let firstWord := calldataload(196)

            let source := and(UINT8_MASK, shr(88, firstWord))
            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator paramter the caller of flashLoan
            switch source
            case 11 {
                if xor(caller(), HANA) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 50 {
                if xor(caller(), AVALON) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 51 {
                if xor(caller(), AVALON_SOLV_BTC) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 55 {
                if xor(caller(), AVALON_USDA) {
                    mstore(0, INVALID_CALLER)
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
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the origCaller
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, firstWord)
            // shift / slice params
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(
            origCaller,
            217, // 196 +21 as constant offset
            calldataLength
        );
        return true;
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
