
export const templateBalancerV3 = (
    constants: string,
    switchCaseContent: string,
) => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Contract Module taking Balancer V3 callbacks
 */
abstract contract BalancerV3Callbacks is Masks, DeltaErrors {
    // v3 vault addresses
    ${constants}
    /**
     * Callback from balancer V3 type vaults
     * Note that this selector is a custom choice
     */
    function balancerUnlockCallback(bytes calldata) external {
        address callerAddress;
        uint256 length;
        uint256 poolId;
        assembly {
            poolId := calldataload(68)
            callerAddress := shr(96, poolId)
            poolId := and(UINT8_MASK, shr(88, poolId))
            // cut off address and poolId
            length := sub(calldataload(36), 21)

            /** Ensure that the caller is the singleton of choice */
            switch poolId
            ${switchCaseContent}
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
            89, // natural offset is 68 plus selector plus addres plus poolId
            length //
        );
    }

    /** A composer contract should override this */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
`
