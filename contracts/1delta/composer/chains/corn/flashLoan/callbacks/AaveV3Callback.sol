// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave v3 flash loan callback
 */
contract AaveV3FlashLoanCallback is Masks, DeltaErrors {
    // Aave V3 style lender pool addresses
    address private constant ZEROLEND = 0x927b3A8e5068840C9758b0b88207b28aeeb7a3fd;
    address private constant AVALON = 0xd412D77A4920317ffb3F5deBAD29B1662FBA53DF;
    address private constant AVALON_SOLVBTC = 0xd63C731c8fBC672B69257f70C47BD8e82C9efBb8;
    address private constant AVALON_PUMPBTC = 0xdef0EB584700Fc81C73ACcd555cB6cea5FB85C3e;
    address private constant AVALON_USDA = 0xf659a3fa012f5847067239a6009309323011815d;
    address private constant AVALON_LBTC = 0xC1bFbF4E0AdCA79790bfa0A557E4080F05e2B438;

    /**
     * @notice Handles Aave V3 flash loan callback
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
            // the initiator parameter the caller of flashLoan
            let pool
            switch and(UINT8_MASK, shr(88, firstWord))
            case 20 { pool := ZEROLEND }
            case 50 { pool := AVALON }
            case 51 { pool := AVALON_SOLVBTC }
            case 53 { pool := AVALON_PUMPBTC }
            case 55 { pool := AVALON_USDA }
            case 66 { pool := AVALON_LBTC }

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
            // an Aave V3 type lending pool
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

    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for flash loan callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}

