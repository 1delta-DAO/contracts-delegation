// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {V2ReferencesBase} from "./V2References.sol";
import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";
import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";

/**
 * @title Contract Module for general Margin Trading on an borrow delegation compatible Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract UniV2Callbacks is V2ReferencesBase, ERC20Selectors, Masks, DeltaErrors {
    // solidly
    bytes32 private constant SELECTOR_HOOK = 0x9a7bff7900000000000000000000000000000000000000000000000000000000;
    // v2 classic
    bytes32 private constant SELECTOR_UNIV2 = 0x10d1e85c00000000000000000000000000000000000000000000000000000000;

    /**
     * Generic Uniswap v2 style callbck executor
     */
    function _executeUniV2IfSelector(bytes32 selector) internal {
        bytes32 codeHash;
        bytes32 ffFactoryAddress;
        bool isUniV2;
        assembly {
            if or(eq(selector, SELECTOR_UNIV2), eq(selector, SELECTOR_HOOK)) {
                switch and(UINT8_MASK, shr(136, calldataload(224))) // forkId
                case 0 {
                    ffFactoryAddress := UNI_V2_FF_FACTORY
                    codeHash := CODE_HASH_UNI_V2
                }
                default {
                    revert(0, 0)
                }
                isUniV2 := 1
            }
        }

        if (isUniV2) {
            uint256 calldataLength;
            address callerAddress;
            uint256 amountIn;
            uint256 amountOut;
            assembly {
                // revert if sender param is not this address
                if xor(calldataload(4), address()) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }

                // get tokens
                let tokenIn := shr(96, calldataload(184))
                let tokenOut := shr(96, calldataload(204))

                let ptr := mload(0x40)
                switch lt(tokenIn, tokenOut)
                case 0 {
                    mstore(add(ptr, 0x14), tokenIn)
                    mstore(ptr, tokenOut)
                }
                default {
                    mstore(add(ptr, 0x14), tokenOut)
                    mstore(ptr, tokenIn)
                }
                let salt := keccak256(add(ptr, 0x0C), 0x28)

                mstore(ptr, ffFactoryAddress)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), codeHash)

                // verify that the caller is a v2 type pool
                if xor(and(ADDRESS_MASK, keccak256(ptr, 0x55)), caller()) {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }

                // get remaining params
                let amount0 := calldataload(36)
                amountIn := calldataload(224)
                calldataLength := and(UINT16_MASK, shr(120, amountIn))
                amountIn := shr(144, amountIn)

                switch iszero(amount0)
                case 1 {
                    // amountOut is amount1
                    amountOut := calldataload(68)
                }
                default {
                    amountOut := amount0
                }
                // get caller address as provided in the call setup
                callerAddress := shr(96, calldataload(164))
            }
            _deltaComposeInternal(
                callerAddress,
                amountIn,
                amountOut,
                // the naive offset is 164
                // we skip the entire callback validation data
                // that is tokens (+40), caller (+20), dexId (+1) datalength (+2) + amountIn (14)
                // = 241
                241,
                calldataLength
            );
            // force return
            assembly {
                return(0, 0)
            }
        }
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
