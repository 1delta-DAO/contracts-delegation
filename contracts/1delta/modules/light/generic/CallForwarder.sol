// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";

/**
 * @notice An arbitrary call contract
 * Does pull funds!
 */
contract CallForwarder_UNFINISHED is Masks, ERC20Selectors {
    // InvalidSwapCall()
    bytes4 private constant INVALID_SWAP_CALL = 0xee68db59;

    /// @dev mask for selector in calldata
    bytes32 private constant SELECTOR_MASK = 0xffffffff00000000000000000000000000000000000000000000000000000000;

    /**
     * There are these following configurations
     * AssetIn:
     *  1) transferFrom
     *  2) native
     *  3) transferTo (sweep back)
     *  4) nothing (assume that the contract is pre-funded (ideal scenario))
     * 
     * AssetOut
     *  1) nothing
     *  2) validate and Sweep 
     * 
     * asset = address(0) means that the asset is native
     * 
     * CallTarget
     *  - Call any target with calldata prvided
     *  - if asset in is nonzero, approve
     *  - approvals are managed via a custom mapping
     * 
     * Validate that we do not call `transferFrom` unvalidated.
     * 
     * Only uses a fallback to skip abi coding
     * The expected pattern is
     *
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 1              | assetInMode                     |
     * | 1      | 20             | assetIn                         |
     * | 21     | 1              | assetOutMode                    |
     * | 22     | 20             | assetOut                        |
     * | 22     | 20             | outReceiver                     |
     * | 42     | 32             | amounts                         |
     * | 42     | 20             | target                          |
     * | 62     | 2              | clLength                        |
     * | 64     | clLength       | calldata                        |
     */
    fallback() external payable {
        assembly {
            let word := calldataload(0)
            let assetIn := shr(96, word)
            let assetInMode := shr(88, word)

            let temp

            let val
            switch assetInMode
            // pull
            case 0 {
                if iszero(assetIn) {
                    revert(0, 0)
                }
                val := 0
            }
            // attach native
            case 1 {
                if xor(0, assetIn) {
                    revert(0, 0)
                }
                val := callvalue()
            }
            // otherwise do nothing

            word := calldataload(21)
            let assetOut := shr(96, word)
            let assetOutMode := shr(88, word)
            word := calldataload(41)

            let len := and(UINT8_MASK, word)

            // extract the selector from the calldata
            let selector := and(SELECTOR_MASK, calldataload(99))

            // check if it is `transferFrom`
            if eq(selector, ERC20_TRANSFER_FROM) {
                mstore(0x0, INVALID_SWAP_CALL)
                revert(0x0, 0x4)
            }


            let ptr := mload(0x40)
            calldatacopy(ptr, 90, len)
            if iszero(
                call(
                    gas(),
                    shr(96, word), // target
                    val,
                    ptr, //
                    len, // the length must be correct or the call will fail
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            switch assetOutMode
            // sweep
            case 0 {
                switch assetOut
                case 0 {

                }
                default {

                }
            }
            case 1 {

            }

            switch assetOutMode
            // sweep
            case 0 {
                switch assetOut
                case 0 {

                }
                default {

                }
            }
            case 1 {

            }
        }
    }
}
