// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {V4ReferencesBase} from "./V4References.sol";
import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";
import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";

/**
 * @title Contract Module taking Uniswap V4 callbacks
 */
abstract contract UniV4Callbacks is V4ReferencesBase, ERC20Selectors, Masks, DeltaErrors {
    /**
     * Callback from uniswap V4 type singletons
     * As Balancer V3 shares the same trigger selector and (unlike this one) has
     * a custom selector provided, we need to skip this part of the data
     * This is mainly done to not have duplicate code and maintain
     * the same level of security by callback validation for both DEX types
     */
    function unlockCallback(
        bytes calldata
    )
        external
        returns (
            // ignored - assigning it costs additional gas
            bytes memory
        )
    {
        address callerAddress;
        uint256 length;
        assembly {
            length := calldataload(36)
            let poolId := calldataload(136)
            callerAddress := and(ADDRESS_MASK, shr(88, poolId))
            poolId := shr(248, poolId)
            // cut off address and poolId
            length := sub(length, 89)

            /** Ensure that the caller is the singleton of choice */
            switch poolId
            case 0 {
                if xor(caller(), UNI_V4_PM) {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }
            }
            default {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        /**
         * This is to execute swaps or flash laons
         * For swaps, one needs to bump the composer swap command in here
         * For Flash loan, the composer commands for take, sync and settle
         * have to be executed
         */
        _deltaComposeInternal(
            callerAddress,
            0,
            0,
            // this is
            //  68 native (selector, offs, len)
            //  4 b3 selector
            //  32 offset
            //  32 length
            //  1 poolId
            //  20 address
            // = 159
            159,
            length //
        );
    }

    /** A composer contract should override this */
    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
