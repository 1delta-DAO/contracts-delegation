// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * \
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */

/**
 * @title GMX V1 swapper, works for most forks, too
 */
abstract contract GMXSwapper {
    /**
     * Swaps exact input on GMX & fork spot DEX
     * @param tokenIn input
     * @param tokenOut output
     * @param vault GMX fork vault address
     * @return amountOut buy amount
     */
    function swapGMXExactIn(
        address tokenIn,
        address tokenOut,
        address vault,
        address receiver //
    )
        internal
        returns (uint256 amountOut)
    {
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
