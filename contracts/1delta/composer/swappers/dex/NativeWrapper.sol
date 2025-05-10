// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

// solhint-disable max-line-length

import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../../shared/masks/Masks.sol";

/**
 * @title native wrap "swapper" contract
 */
abstract contract NativeWrapper is ERC20Selectors, Masks {
    // NativeTransferFailed()
    bytes4 private constant NATIVE_TRANSFER = 0xf4b3b1bc;
    // WrapFailed()
    bytes4 private constant WRAP = 0xc30d93ce;

    // Wraps  or unwraps
    // Note that the wrap call is a plain native transfer
    /**
     * This one is for overring the DEX implementation
     * | Offset | Length (bytes) | Description         |
     * |--------|----------------|---------------------|
     * | 0      | 20             | wrappedNativeAddress|
     * | 20     | 1              | isWrap              |
     */
    function _wrapOrUnwrapSimple(uint256 amount, uint256 currentOffset) internal virtual returns (uint256, uint256) {
        assembly {
            /**
             * This is extensible, for now, we have
             * wrap: 1 (this is equivalent to asset{value:amount}.call(""))
             * unwrap: 0
             */
            let asset := calldataload(currentOffset)
            let wrap := shr(88, calldataload(currentOffset))
            asset := shr(96, asset)
            switch wrap
            case 0 {
                // selector for withdraw(uint256)
                mstore(0x0, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                mstore(0x4, amount)
                if iszero(
                    call(
                        gas(),
                        asset,
                        0x0, // no ETH
                        0x0, // start of data
                        0x24, // input size = selector plus amount
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                ) {
                    // revert when native transfer fails
                    mstore(0, WRAP)
                    revert(0, 0x4)
                }
            }
            default {
                if iszero(
                    call(
                        gas(),
                        asset,
                        amount, // ETH to deposit
                        0x0, // no input
                        0x0, // input size = zero
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                ) {
                    // revert when native transfer fails
                    mstore(0, NATIVE_TRANSFER)
                    revert(0, 0x4)
                }
            }
            currentOffset := add(currentOffset, 21)
        }
        return (currentOffset, amount);
    }
}
