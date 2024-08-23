// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

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

    /// @dev WooFi rebate receiver
    address internal constant REBATE_RECIPIENT = 0x48CA3E658eCB84eE283dc21e475c22b5cc5d3f3C;

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
}
