// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

import {Masks} from "../masks/Masks.sol";

/**
 * @title DodoV2 swapper contract
 */
abstract contract DodoV2Swapper is Masks {
    /** Spot */

    /**
     * Executes a swap on DODO V2 exact in
     * The pair address is fetched from the factory
     * @param sellQuote if 0, the selector is `sellBase`, otherwise use sellBase
     * @param pair pair address
     * @param receiver receiver address
     * @return amountOut buy amount
     */
    function swapDodoV2ExactIn(uint8 sellQuote, address pair, address receiver) internal returns (uint256 amountOut) {
        assembly {
            // determine selector
            switch sellQuote
            case 0 {
                // sellBase
                mstore(0x0, 0xbd6015b400000000000000000000000000000000000000000000000000000000)
            }
            default {
                // sellQuote
                mstore(0x0, 0xdd93f59a00000000000000000000000000000000000000000000000000000000)
            }
            mstore(0x4, receiver)
            // call swap, revert if invalid/undefined pair
            if iszero(call(gas(), pair, 0x0, 0x0, 0x24, 0x0, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // the swap call returns the output amount directly
            amountOut := mload(0x0)
        }
    }

    /** Flash Loan & Swap */

    // InvalidCaller()
    bytes4 private constant INVALID_CALLER = 0x48f5c3ed;

    bytes32 private constant FLASH_LOAN_GATEWAY_SLOT_1 = 0x9fc772e484014aadda1a3916bdcbf34dd65a99500e92cb6faae6cb2496083ccc;

    /**
     * Executes a swap on DODO V2 exact in using flash loans
     * We have to quote first to determine the output amount
     * The input amount is attached in the calldata
     * Callback MUST use validatr below
     */
    function flashSwapDodoV2ExactIn(
        uint256 amountIn,
        uint256 amountOutMin,
        address payer, //
        uint256 pathOffset,
        uint256 pathLength
    ) internal {
        assembly {
            let ptr := mload(0x40)

            let pair := calldataload(add(pathOffset, 22))

            let baseAm
            let quoteAm
            // get flag for direction
            let isSellQuote := and(shr(88, pair), UINT8_MASK)

            // mask pair
            pair := shr(96, pair)
            // determine selector
            switch isSellQuote
            case 0 {
                // sellBase
                baseAm := 0
                // querySellBase(address,uint256)
                mstore(ptr, 0x79a0487600000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), 0) // trader is zero
                mstore(add(ptr, 0x24), amountIn)
                if iszero(
                    staticcall(
                        gas(),
                        pair,
                        ptr,
                        0x44, //
                        0x0,
                        0x20
                    )
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                quoteAm := mload(0)
            }
            default {
                // sellQuote
                // querySellBase(address,uint256)
                mstore(ptr, 0x66410a2100000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), 0) // trader is zero
                mstore(add(ptr, 0x24), amountIn)
                if iszero(
                    staticcall(
                        gas(),
                        pair,
                        ptr,
                        0x44, //
                        0x0,
                        0x20
                    )
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                baseAm := mload(0)
            }
            /** Similar to Uni V2 flash swaps */
            // flashLoan(
            //     uint256 baseAmount,
            //     uint256 quoteAmount,
            //     address assetTo,
            //     bytes calldata data
            // )
            mstore(ptr, 0xd0a494e400000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), baseAm)
            mstore(add(ptr, 0x24), quoteAm)
            mstore(add(ptr, 0x44), address())
            mstore(add(ptr, 0x64), 0x80) // bytes offset
            // we store the offset of the bytes calldata in the func call
            let calldataOffsetStart := add(ptr, 0xA4)
            let _pathLength := pathLength
            calldatacopy(calldataOffsetStart, pathOffset, _pathLength)
            // store max amount
            mstore(add(calldataOffsetStart, _pathLength), shl(128, amountOutMin))
            // store amountIn
            mstore(add(calldataOffsetStart, add(_pathLength, 16)), shl(128, amountIn))
            _pathLength := add(_pathLength, 32)
            // store payer
            mstore(add(calldataOffsetStart, _pathLength), shl(96, payer))
            _pathLength := add(_pathLength, 20)
            // bytes length
            mstore(add(ptr, 0x84), _pathLength)
            // set entry flag
            sstore(FLASH_LOAN_GATEWAY_SLOT_1, 2)
            // call swap, revert if invalid/undefined pair
            if iszero(
                call(
                    gas(),
                    pair,
                    0x0, // no native
                    ptr,
                    add(0xA4, _pathLength), // input size = 164 (selector (4bytes) plus 5*32bytes)
                    0x0,
                    0x0
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // unset entry flasg
            sstore(FLASH_LOAN_GATEWAY_SLOT_1, 1)
        }
    }

    /** Check that the initiator is thois contract and that the flash loan flag is set */
    function _validateDodoV2FlashLoan(address initiator) internal view {
        assembly {
            // We require to self-initiate
            // this prevents payer impersonation,
            // only in combination with the flash entry flag
            if xor(address(), initiator) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }

            // check that the entry flag is
            if iszero(eq(2, sload(FLASH_LOAN_GATEWAY_SLOT_1))) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
        }
    }
}
