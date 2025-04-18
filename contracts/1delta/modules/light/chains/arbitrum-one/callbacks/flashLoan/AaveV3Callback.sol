// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave v3 flash loan callback
 */
contract AaveV3FlashLoanCallback is Masks, DeltaErrors {
    // Aave V3 style lender pool addresses
    address private constant AAVE_V3 = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address private constant AVALON = 0xe1ee45DB12ac98d16F1342a03c93673d74527b55;
    address private constant AVALON_PUMP_BTC = 0x4B801fb6f0830D070f40aff9ADFC8f6939Cc1F8D;
    address private constant YLDR = 0x54aD657851b6Ae95bA3380704996CAAd4b7751A3;

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
            case 0 {
                if xor(caller(), AAVE_V3) {
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
            case 53 {
                if xor(caller(), AVALON_PUMP_BTC) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 100 {
                if xor(caller(), YLDR) {
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
