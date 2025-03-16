// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {V2ReferencesBase} from "./V2References.sol";
import {V3ReferencesBase} from "./V3References.sol";
import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";
import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";

/**
 * @title Contract Module for general Margin Trading on an borrow delegation compatible Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract UniV3Callbacks is V2ReferencesBase, V3ReferencesBase, ERC20Selectors, Masks, DeltaErrors {
    // errors
    error NoBalance();

    uint256 internal constant PATH_OFFSET_CALLBACK_V2 = 164;
    uint256 internal constant PATH_OFFSET_CALLBACK_V3 = 132;
    uint256 internal constant NEXT_SWAP_V3_OFFSET = 176; //PATH_OFFSET_CALLBACK_V3 + SKIP_LENGTH_UNOSWAP;
    uint256 internal constant NEXT_SWAP_V2_OFFSET = 208; //PATH_OFFSET_CALLBACK_V2 + SKIP_LENGTH_UNOSWAP;

    // offset for receiver address for most DEX types (uniswap, curve etc.)
    uint256 private constant RECEIVER_OFFSET_UNOSWAP = 66;
    uint256 private constant MAX_SINGLE_LENGTH_UNOSWAP = 67;
    /// @dev higher length limit for path length using lt()
    uint256 private constant MAX_SINGLE_LENGTH_UNOSWAP_HIGH = 68;
    uint256 private constant SKIP_LENGTH_UNOSWAP = 44; // = 20+1+1+20+2

    constructor() {}

    // uniswap v3
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external {
        address tokenIn;
        address tokenOut;
        address callerAddress;
        uint256 pathLength;
        assembly {
            let firstWord := calldataload(PATH_OFFSET_CALLBACK_V3)
            callerAddress := shr(96, firstWord)
            firstWord := calldataload(add(20, PATH_OFFSET_CALLBACK_V3))
            tokenIn := shr(96, firstWord)
            firstWord := calldataload(add(40, PATH_OFFSET_CALLBACK_V3))
            // second word
            // firstWord := calldataload(164) // PATH_OFFSET_CALLBACK_V3 + 32
            tokenOut := shr(96, firstWord)
            let dexId := and(UINT8_MASK, shr(88, firstWord))
            pathLength := and(UINT16_MASK, shr(48, firstWord))

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            switch dexId
            case 0 {
                mstore(s, UNI_V3_FF_FACTORY)
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
                mstore(add(p, 64), and(UINT16_MASK, shr(72, firstWord)))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, UNI_POOL_INIT_CODE_HASH)
            }
            default {
                revert(0, 0)
            }
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, callerAddress, pathLength);
    }

    function clSwapCallback(int256 amount0Delta, int256 amount1Delta, address tokenIn, address callerAddress, uint256 pathLength) private {
        uint256 amountToPay;
        uint256 amountReceived;
        assembly {
            switch sgt(amount0Delta, 0)
            case 1 {
                amountReceived := sub(0, amount1Delta)
                amountToPay := amount0Delta
            }
            default {
                amountReceived := sub(0, amount0Delta)
                amountToPay := amount1Delta
            }

            // one can pass no path to continue
            // we then assume the pathLength as flag to
            // indicate the pay type
            if lt(pathLength, 2) {
                let ptr := mload(0x40)

                let success
                // transfer from caller
                switch pathLength
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
                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            iszero(lt(rdsize, 32)), // at least 32 bytes
                            eq(mload(ptr), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
                return(0, 0)
            }
        }
        _deltaComposeInternal(callerAddress, amountReceived, amountToPay, 0x96, pathLength);
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
