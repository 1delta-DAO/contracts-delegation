// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave V2 flash loan callback
 */
contract AaveV2FlashLoanCallback is Masks, DeltaErrors {
    // Aave v2s
    address private constant GRANARY = 0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3;
    address private constant POLTER = 0x33CA62504cebAB919f0FCa94562413ee121A9798;
    address private constant RADIANT_V2 = 0x30798cFe2CCa822321ceed7e6085e633aAbC492F;
    address private constant PRIME_FI = 0x8a619D8E3BfAb54F7C30Ef39Ce16c53429c739C3;

    /**
     * @notice Handles Aave V2 flash loan callback
     * @dev Validates caller, extracts original caller from params, and executes compose operations
     * @param initiator The address that initiated the flash loan
     
     * @return Always returns true on success
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | origCaller                   |
     * | 20     | 1              | poolId                       |
     * | 21     | Variable       | composeOperations           |
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
            // the initiator parameter the caller of flashLoan
            let pool
            switch and(UINT8_MASK, shr(88, firstWord))
            case 7 { pool := GRANARY }
            case 11 { pool := POLTER }
            case 20 { pool := RADIANT_V2 }
            case 21 { pool := PRIME_FI }
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
            // Slice the original caller off the beginning of the calldata
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

    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for flash loan callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
