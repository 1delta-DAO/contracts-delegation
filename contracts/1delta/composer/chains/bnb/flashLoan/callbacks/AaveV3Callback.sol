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
    address private constant AVALON_SOLV_BTC = 0xf9278C7c4AEfAC4dDfd0D496f7a1C39cA6BCA6d4;
    address private constant AVALON_PUMP_BTC = 0xeCaC6332e2De19e8c8e6Cd905cb134E980F18cC4;
    address private constant AVALON_STBTC = 0x05C194eE95370ED803B1526f26EFd98C79078ab5;
    address private constant AVALON_WBTC = 0xF8718Fc27eF04633B7EB372F778348dE02642207;
    address private constant AVALON_LBTC = 0x390166389f5D30281B9bDE086805eb3c9A10F46F;
    address private constant AVALON_XAUM = 0x4B801fb6f0830D070f40aff9ADFC8f6939Cc1F8D;
    address private constant AVALON_LISTA = 0x54925C6dDeB73A962B3C3A21B10732eD5548e43a;
    address private constant AVALON_USDX = 0x77fF9B0cdbb6039b9D42d92d7289110E6CCD3890;
    address private constant KINZA = 0xcB0620b181140e57D1C0D8b724cde623cA963c8C;

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
            case 51 {
                if xor(caller(), AVALON_SOLV_BTC) {
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
            case 64 {
                if xor(caller(), AVALON_STBTC) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 65 {
                if xor(caller(), AVALON_WBTC) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 66 {
                if xor(caller(), AVALON_LBTC) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 67 {
                if xor(caller(), AVALON_XAUM) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 68 {
                if xor(caller(), AVALON_LISTA) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 69 {
                if xor(caller(), AVALON_USDX) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            case 82 {
                if xor(caller(), KINZA) {
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
