// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave V2 flash loan callback
 */
contract AaveV2FlashLoanCallback is Masks, DeltaErrors {
    // Aave v2s
    address private constant GRANARY = 0x7171054f8d148Fe1097948923C91A6596fC29032;
    address private constant VALAS = 0xE29A55A6AEFf5C8B1beedE5bCF2F0Cb3AF8F91f5;
    address private constant RADIANT_V2 = 0xCcf31D54C3A94f67b8cEFF8DD771DE5846dA032c;

    /**
     * @dev Aave V2 style flash loan callback
     */
    function executeOperation(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata, // we assume that the data is known to the caller in advance
        address initiator,
        bytes calldata params
    )
        external
        returns (bool)
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

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator paramter the caller of flashLoan
            let pool
            switch and(UINT8_MASK, shr(88, firstWord))
            case 7 { pool := GRANARY }
            case 16 { pool := VALAS }
            case 20 { pool := RADIANT_V2 }
            // We revert on any other id
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // revert if caller is not a whitelisted pool
            if xor(caller(), pool) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }

            // We require to self-initiate
            // this prevents caller impersonation,
            // but ONLY if the caller address is
            // an Aave V2 type lending pool
            if xor(address(), initiator) {
                mstore(0, INVALID_INITIATOR)
                revert(0, 0x4)
            }
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
        // we pass the payAmount and loaned amount for consistent usage
        _deltaComposeInternal(origCaller, calldataOffset, calldataLength);
        return true;
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
