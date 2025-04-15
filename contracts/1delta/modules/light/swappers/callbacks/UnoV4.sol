// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

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
    function unlockCallback(bytes calldata) external {
        address callerAddress;
        uint256 length;
        assembly {
            let poolId := calldataload(136)
            // callerAddress populates the first 20 bytes
            callerAddress := shr(96, poolId)
            poolId := and(UINT8_MASK, shr(88, poolId))
            // cut off address and poolId
            length := sub(calldataload(36), 89)

            /**
             * Ensure that the caller is the singleton of choice
             */
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
            // this is
            //  68 native (selector, offs, len)
            //  4 b3 selector
            //  32 offset
            //  32 length
            //  1 poolId
            //  20 address
            // = 157
            157,
            length //
        );

        // return empty bytes
        assembly {
            mstore(0x0, 0x0)
            mstore(0x20, 0x0)
            return(0x0, 0x40)
        }
    }

    /**
     * A composer contract should override this
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
