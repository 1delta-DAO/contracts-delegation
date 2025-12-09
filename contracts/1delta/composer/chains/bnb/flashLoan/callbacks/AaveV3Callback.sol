// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave v3 flash loan callback
 */
contract AaveV3FlashLoanCallback is Masks, DeltaErrors {
    // Aave V3 style lender pool addresses
    address private constant AAVE_V3 = 0x6807dc923806fE8Fd134338EABCA509979a7e0cB;
    address private constant AVALON_SOLVBTC = 0xf9278C7c4AEfAC4dDfd0D496f7a1C39cA6BCA6d4;
    address private constant AVALON_PUMPBTC = 0xeCaC6332e2De19e8c8e6Cd905cb134E980F18cC4;
    address private constant AVALON_STBTC = 0x05C194eE95370ED803B1526f26EFd98C79078ab5;
    address private constant AVALON_WBTC = 0xF8718Fc27eF04633B7EB372F778348dE02642207;
    address private constant AVALON_LBTC = 0x390166389f5D30281B9bDE086805eb3c9A10F46F;
    address private constant AVALON_XAUM = 0x4B801fb6f0830D070f40aff9ADFC8f6939Cc1F8D;
    address private constant AVALON_LISTA = 0x54925C6dDeB73A962B3C3A21B10732eD5548e43a;
    address private constant AVALON_USDX = 0x77fF9B0cdbb6039b9D42d92d7289110E6CCD3890;
    address private constant AVALON_UNIBTC = 0x795Ae4Bd3B63aA8657a7CC2b3e45Fb0F7c9ED9Cc;
    address private constant KINZA = 0xcB0620b181140e57D1C0D8b724cde623cA963c8C;

    /**
     * @notice Handles Aave V3 flash loan callback
     * @dev Validates caller, extracts original caller from params, and executes compose operations
     * @param initiator The address that initiated the flash loan
     * @param params Calldata containing the original caller and compose operations
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

            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator parameter the caller of flashLoan
            let pool
            let poolId := and(UINT8_MASK, shr(88, firstWord))

            switch lt(poolId, 54)
            case 1 {
                switch poolId
                case 0 { pool := AAVE_V3 }
                case 51 { pool := AVALON_SOLVBTC }
                case 53 { pool := AVALON_PUMPBTC }
            }
            default {
                switch lt(poolId, 67)
                case 1 {
                    switch poolId
                    case 64 { pool := AVALON_STBTC }
                    case 65 { pool := AVALON_WBTC }
                    case 66 { pool := AVALON_LBTC }
                }
                default {
                    switch poolId
                    case 67 { pool := AVALON_XAUM }
                    case 68 { pool := AVALON_LISTA }
                    case 69 { pool := AVALON_USDX }
                    case 70 { pool := AVALON_UNIBTC }
                    case 82 { pool := KINZA }
                }
            }

            // catch unassigned pool / bad poolId
            if iszero(pool) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // match pool address
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

