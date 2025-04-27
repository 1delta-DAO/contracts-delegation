// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave v3 flash loan callback
 */
contract AaveV3FlashLoanCallback is Masks, DeltaErrors {
    // Aave V3 style lender pool addresses
    address private constant AAVE_V3 = 0xc47b8C00b0f69a36fa203Ffeac0334874574a8Ac;
    address private constant ZEROLEND = 0x2f9bB73a8e98793e26Cb2F6C4ad037BDf1C6B269;
    address private constant ZEROLEND_CROAK = 0xc6ff96AefD1cC757d56e1E8Dcc4633dD7AA5222D;
    address private constant ZEROLEND_FOXY = 0xbDAa004A456E7f2dAff00FfcDCbEaD5da27B7966;

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

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator paramter the caller of flashLoan
            switch and(UINT8_MASK, shr(88, firstWord))
            case 0 {
                if xor(caller(), AAVE_V3) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 20 {
                if xor(caller(), ZEROLEND) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 24 {
                if xor(caller(), ZEROLEND_CROAK) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 25 {
                if xor(caller(), ZEROLEND_FOXY) {
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
