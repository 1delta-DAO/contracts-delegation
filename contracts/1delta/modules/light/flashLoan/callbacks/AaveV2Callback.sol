// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";

/**
 * @title Universal aggregator contract.
 *        Allows spot and margin swap aggregation
 *        Efficient baching through compact calldata usage.
 * @author 1delta Labs AG
 */
contract AaveV2FlashLoanCallback is Masks, DeltaErrors {
    // Aave v2s
    address private constant GRANARY = 0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3;

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
        uint256 amount;
        uint256 toPay;
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
            case 0 {
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
            // we load the amounts here from the raw calldata
            // these are in the arrays of length 1
            amount := calldataload(260)
            toPay := add(amount, calldataload(324))
        }
        // within the flash loan, any compose operation
        // can be executed
        // we pass the payAmount and loaned amount for consistent usage
        _deltaComposeInternal(origCaller, toPay, amount, calldataOffset, calldataLength);
        return true;
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
