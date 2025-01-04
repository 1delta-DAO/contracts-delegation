// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {CurveSwapper} from "./Curve.sol";

// solhint-disable max-line-length

/**
 * @title Exotic swapper contract
 * @notice Typically includes DEXs that do not fall into a broader category
 */
abstract contract ExoticSwapper is CurveSwapper {
    /// @dev Maximum high path length of a dex that only has a pool address reference
    uint256 internal constant RECEIVER_OFFSET_SINGLE_LENGTH_ADDRESS = 64;
    uint256 internal constant MAX_SINGLE_LENGTH_ADDRESS = 65;
    uint256 internal constant MAX_SINGLE_LENGTH_ADDRESS_HIGH = 66;
    
    /// @dev Length of a swap that only has a pool address reference
    uint256 internal constant SKIP_LENGTH_ADDRESS = 42; // = 20+1+1+20

    /// @dev Maximum high path length for pool address and param (u8)
    uint256 internal constant RECEIVER_OFFSET_SINGLE_LENGTH_ADDRESS_AND_PARAM = 65;
    uint256 internal constant MAX_SINGLE_LENGTH_ADDRESS_AND_PARAM = 66;
    uint256 internal constant MAX_SINGLE_LENGTH_ADDRESS_AND_PARAM_HIGH = 67;
    
    /// @dev Length of a swap that only has a pool address an param (u8)
    uint256 internal constant SKIP_LENGTH_ADDRESS_AND_PARAM = 43; // = 20+1+1+20

    /// @dev WooFi rebate receiver
    address internal constant REBATE_RECIPIENT = 0x0000000000000000000000000000000000000000;

    constructor() {}

    /**
     * Swaps exact input on WOOFi DEX
     * @param tokenIn input
     * @param tokenOut output
     * @param amountIn sell amount
     * @return amountOut buy amount
     */
    function swapWooFiExactIn(
        address tokenIn,
        address tokenOut,
        address pool,
        uint256 amountIn,
        address receiver
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            // selector for swap(address,address,uint256,uint256,address,address)
            mstore(
                ptr, //
                0x7dc2038200000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x04), tokenIn)
            mstore(add(ptr, 0x24), tokenOut)
            mstore(add(ptr, 0x44), amountIn)
            mstore(add(ptr, 0x64), 0x0) // amountOutMin unused
            mstore(add(ptr, 0x84), receiver) // recipient
            mstore(add(ptr, 0xA4), REBATE_RECIPIENT) // rebateTo
            if iszero(
                call(
                    gas(),
                    pool,
                    0x0, // no native transfer
                    ptr,
                    0xC4, // input length 196
                    ptr, // store output here
                    0x20 // output is just uint
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            amountOut := mload(ptr)
        }
    }

    /**
     * Swaps exact input on KTX spot DEX
     * @param tokenIn input
     * @param tokenOut output
     * @param vault GMX fork vault address
     * @return amountOut buy amount
     */
    function swapGMXExactIn(
        address tokenIn, 
        address tokenOut, 
        address vault,
        address receiver
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            // selector for swap(address,address,address)
            mstore(
                ptr, //
                0x9331621200000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x04), tokenIn)
            mstore(add(ptr, 0x24), tokenOut)
            mstore(add(ptr, 0x44), receiver)
            if iszero(
                call(
                    gas(),
                    vault,
                    0x0, // no native transfer
                    ptr,
                    0x64, // input length 66 bytes
                    ptr, // store output here
                    0x20 // output is just uint
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            amountOut := mload(ptr)
        }
    }

    /**
     * Executes a swap on merchant Moe's LB exact in
     * The pair address is fetched from the factory
     * @param tokenOut output
     * @param pair pair address
     * @param receiver receiver address
     * @return amountOut buy amount
     */
    function swapLBexactIn(
        address tokenOut,
        address pair,
        address receiver
    ) internal returns (uint256 amountOut) {
        assembly {
            // getTokenY()
            mstore(0x0, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            if iszero(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pair,
                    0x0,
                    0x4, // selector only
                    0x0,
                    0x20
                )
            ) {
                revert (0, 0)
            }
            let swapForY := eq(tokenOut, mload(0x0)) 
            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////

            let ptr := mload(0x40)
            // swap(bool,address)
            mstore(ptr, 0x53c059a000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), swapForY)
            mstore(add(ptr, 0x24), receiver)
            // call swap, revert if invalid/undefined pair
            if iszero(call(gas(), pair, 0x0, ptr, 0x44, ptr, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // the swap call returns both amounts encoded into a single bytes32 as (amountX,amountY)
            switch swapForY
            case 0 {
                amountOut := and(mload(ptr), 0xffffffffffffffffffffffffffffffff)
            }
            default {
                amountOut := shr(128, mload(ptr))
            }
        }
    }

    /**
     * Swaps Merchant Moe's LB exact output internally
     * @param pair address provided byt the factory
     * @param swapForY flag for tokenY being the output token
     * @param amountOut amountOut used to validate that we received enough
     * @param receiver receiver address
     */
    function swapLBexactOut(
        address pair,
        bool swapForY, 
        uint256 amountOut, 
        address receiver
    ) internal {
        assembly {
            let ptr := mload(0x40)

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////

            // swap(bool,address)
            mstore(ptr, 0x53c059a000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), swapForY)
            mstore(add(ptr, 0x24), receiver)
            // call swap, revert if invalid/undefined pair
            if iszero(call(gas(), pair, 0x0, ptr, 0x44, ptr, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            ////////////////////////////////////////////////////
            // Validate amount received
            ////////////////////////////////////////////////////

            // we fetch the amount out we actually got
            let amountOutReceived
            // the swap call returns both amounts encoded into a single bytes32 as (amountX,amountY)
            switch swapForY
            case 0 {
                amountOutReceived := and(mload(ptr), 0xffffffffffffffffffffffffffffffff)
            }
            default {
                amountOutReceived := shr(128, mload(ptr))
            }
            // revert if we did not get enough
            if lt(amountOutReceived, amountOut) {
                revert (0, 0)
            }
        }    
    }

    /**
     * Calculates Merchant Moe's LB amount in
     * @param tokenOut output
     * @param amountOut buy amount
     * @return amountIn buy amount
     * @return swapForY flag for tokenOut = tokenY
     */
    function getLBAmountIn(
        address tokenOut,
        address pair,
        uint256 amountOut
    ) internal view returns (uint256 amountIn, bool swapForY) {
        assembly {
            // getTokenY()
            mstore(0x0, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            if iszero(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pair,
                    0x0,
                    0x4, // selector only
                    0x0,
                    0x20
                )
            ) {
                revert (0, 0)
            }
            // override swapForY
            swapForY := eq(tokenOut, mload(0x0))

            let ptr := mload(0x40)
            // getSwapIn(uint128,bool)
            mstore(ptr, 0xabcd783000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), amountOut)
            mstore(add(ptr, 0x24), swapForY)
            // call swap simulator, revert if invalid/undefined pair
            if iszero(staticcall(gas(), pair, ptr, 0x44, ptr, 0x40)) {
                revert(0, 0)
            }
            amountIn := and(
                0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff, // mask uint128
                mload(ptr)
            )
            // the second slot returns amount out left, if positive, we revert
            if gt(0, mload(add(ptr, 0x20))) {
                revert(0, 0)
            }
        }
    }

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
}
