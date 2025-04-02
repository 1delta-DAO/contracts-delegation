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
    uint256 internal constant PATH_OFFSET_CALLBACK_V2 = 164;

    // The uniswapV2 style callback for exact forks
    function uniswapV2Call(address sender, uint256 a0, uint256 a1, bytes calldata) external {
        address tokenIn;
        address tokenOut;
        address callerAddress;
        uint256 calldataLength;
        uint256 amountIn;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            // revert if sender param is not this address
            if xor(sender, address()) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            callerAddress := shr(96, calldataload(PATH_OFFSET_CALLBACK_V2))

            // get tokens
            tokenIn := shr(96, calldataload(184))
            tokenOut := shr(96, calldataload(204))

            // the next word has more parameters
            let amountDexIdCalldataLength := calldataload(224)
            amountIn := shr(144, amountDexIdCalldataLength)
            let dexId := and(UINT8_MASK, shr(136, amountDexIdCalldataLength))
            calldataLength := and(UINT16_MASK, shr(120, amountDexIdCalldataLength))

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
            // validate callback
            switch dexId
            case 0 {
                mstore(ptr, UNI_V2_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CODE_HASH_UNI_V2)
            }
            default {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
            // verify that the caller is a v2 type pool
            if xor(and(ADDRESS_MASK, keccak256(ptr, 0x55)), caller()) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
            // revert if sender param is not this address
            // this occurs if someone sends valid
            // calldata with this contract as recipient
            if xor(sender, address()) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
        }
        _v2Callback(amountIn, a0, a1, callerAddress, calldataLength);
    }

    function _v2Callback(uint256 amountIn, uint256 a0, uint256 a1, address callerAddress, uint256 calldataLength) internal {
        uint256 amountOut;
        assembly {
            switch iszero(a0)
            case 1 {
                amountOut := a1
            }
            default {
                amountOut := a0
            }
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
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
