// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

// solhint-disable max-line-length

/**
 * @title WooFi swapper contract
 */
abstract contract WooFiSwapper {
    /// @dev WooFi rebate receiver
    address internal constant REBATE_RECIPIENT = 0xC95eED7F6E8334611765F84CEb8ED6270F08907E;

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
    )
        internal
        returns (uint256 amountOut)
    {
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
}
