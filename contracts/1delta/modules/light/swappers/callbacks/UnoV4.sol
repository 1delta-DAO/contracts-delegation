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
    /** Callback fromn uniswap V4 type singletons */
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
            let poolId := calldataload(68)
            callerAddress := and(ADDRESS_MASK, shr(88, poolId))
            poolId := shr(248, poolId)
            // cut off address and poolId
            length := sub(length, 21)

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
            89, // natural offset is 68 plus addres plus poolId
            length //
        );
    }

    /** A composer contract should override this */
    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
