// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {V3ReferencesBase} from "./V3References.sol";
import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";
import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";

/**
 * @title Contract Module for general Margin Trading on an borrow delegation compatible Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract UniV3Callbacks is V3ReferencesBase, ERC20Selectors, Masks, DeltaErrors {
    /// @dev the constant offset a path has for Uni V3 type swap callbacks
    uint256 internal constant PATH_OFFSET_CALLBACK_V3 = 132;

    function clSwapCallback(uint256 amountToPay, uint256 amountReceived, address tokenIn, address callerAddress, uint256 calldataLength) private {
        assembly {
            // one can pass no path to continue
            // we then assume the calldataLength as flag to
            // indicate the pay type
            if lt(calldataLength, 2) {
                let ptr := mload(0x40)

                let success
                // transfer from caller
                switch calldataLength
                case 0 {
                    // selector for transferFrom(address,address,uint256)
                    mstore(ptr, ERC20_TRANSFER_FROM)
                    mstore(add(ptr, 0x04), callerAddress)
                    mstore(add(ptr, 0x24), caller())
                    mstore(add(ptr, 0x44), amountToPay)

                    success := call(gas(), tokenIn, 0, ptr, 0x64, ptr, 32)
                }
                // transfer plain
                default {
                    // selector for transfer(address,uint256)
                    mstore(ptr, ERC20_TRANSFER)
                    mstore(add(ptr, 0x04), caller())
                    mstore(add(ptr, 0x24), amountToPay)
                    success := call(
                        gas(),
                        tokenIn, // tokenIn, pool + 5x uint8 (i,j,s,a)
                        0,
                        ptr,
                        0x44,
                        ptr,
                        32
                    )
                }

                let rdsize := returndatasize()

                if iszero(
                    and(
                        success, // call itself succeeded
                        or(
                            iszero(rdsize), // no return data, or
                            and(
                                gt(rdsize, 31), // at least 32 bytes
                                eq(mload(ptr), 1) // starts with uint256(1)
                            )
                        )
                    )
                ) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
                return(0, 0)
            }
        }
        _deltaComposeInternal(
            callerAddress,
            amountToPay,
            amountReceived,
            // the naive offset is 132
            // we skip the entire callback validation data
            // that is tokens (+40), fee (+2), caller (+20), forkId (+1) datalength (+2)
            // = 197
            197,
            calldataLength
        );
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}

    bytes32 private constant SELECTOR_IZI_XY = 0x1878068400000000000000000000000000000000000000000000000000000000;
    bytes32 private constant SELECTOR_IZI_YX = 0xd3e1c28400000000000000000000000000000000000000000000000000000000;
    bytes32 private constant SELECTOR_UNIV3 = 0xfa461e3300000000000000000000000000000000000000000000000000000000;
    bytes32 private constant SELECTOR_ALGEBRA = 0x2c8958f600000000000000000000000000000000000000000000000000000000;
    bytes32 private constant SELECTOR_PANCAKE = 0x23a69e7500000000000000000000000000000000000000000000000000000000;

    /**
     * Generic UniswapV3 callback executor
     * The call looks like
     * ```function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {...}```
     */
    function _executeUniV3IfSelector(bytes32 selector) internal {
        bytes32 codeHash;
        bytes32 ffFactoryAddress;
        bool isUniV3;
        uint256 amountToPay;
        uint256 amountReceived;
        assembly {
            switch or(eq(selector, SELECTOR_UNIV3), eq(selector, SELECTOR_PANCAKE))
            case 1 {
                switch and(UINT8_MASK, shr(88, calldataload(172))) // forkId
                case 0 {
                    ffFactoryAddress := UNI_V3_FF_FACTORY
                    codeHash := UNI_POOL_INIT_CODE_HASH
                }
                default {
                    revert(0, 0)
                }
                let _amount0 := calldataload(4)
                let _amount1 := calldataload(36)

                switch sgt(_amount1, 0)
                case 0 {
                    amountReceived := sub(0, _amount1)
                    amountToPay := _amount0
                }
                default {
                    amountReceived := sub(0, _amount0)
                    amountToPay := _amount1
                }
                isUniV3 := 1
            }
            default {
                // check if we do izumi
                switch selector
                // SELECTOR_IZI_XY
                case 0x1878068400000000000000000000000000000000000000000000000000000000 {
                    switch and(UINT8_MASK, shr(88, calldataload(172))) // forkId
                    case 0 {
                        ffFactoryAddress := IZI_FF_FACTORY
                        codeHash := IZI_POOL_INIT_CODE_HASH
                    }
                    default {
                        revert(0, 0)
                    }
                    amountToPay := calldataload(4)
                    amountReceived := calldataload(36)
                    isUniV3 := 1
                }
                // SELECTOR_IZI_YX
                case 0xd3e1c28400000000000000000000000000000000000000000000000000000000 {
                    switch and(UINT8_MASK, shr(88, calldataload(172))) // forkId
                    case 0 {
                        ffFactoryAddress := IZI_FF_FACTORY
                        codeHash := IZI_POOL_INIT_CODE_HASH
                    }
                    default {
                        revert(0, 0)
                    }
                    amountReceived := calldataload(4)
                    amountToPay := calldataload(36)
                    isUniV3 := 1
                }
            }
        }

        if (isUniV3) {
            uint256 calldataLength;
            address callerAddress;
            address tokenIn;
            assembly {
                tokenIn := shr(96, calldataload(152))
                let tokenOutAndFee := calldataload(172)
                let tokenOut := shr(96, tokenOutAndFee)
                calldataLength := and(UINT16_MASK, shr(56, tokenOutAndFee))
                let s := mload(0x40)
                mstore(s, ffFactoryAddress)
                let p := add(s, 21)
                // Compute the inner hash in-place
                switch lt(tokenIn, tokenOut)
                case 0 {
                    mstore(p, tokenOut)
                    mstore(add(p, 32), tokenIn)
                }
                default {
                    mstore(p, tokenIn)
                    mstore(add(p, 32), tokenOut)
                }
                // this stores the fee
                mstore(add(p, 64), and(UINT16_MASK, shr(72, tokenOutAndFee)))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, codeHash)

                ////////////////////////////////////////////////////
                // If the caller is not the calculated pool, we revert
                ////////////////////////////////////////////////////
                if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }
                // get original caller address
                callerAddress := shr(96, calldataload(132))
            }
            clSwapCallback(
                amountToPay,
                amountReceived, //
                tokenIn,
                callerAddress,
                calldataLength
            );
            // force return
            assembly {
                return(0, 0)
            }
        }
    }
}
