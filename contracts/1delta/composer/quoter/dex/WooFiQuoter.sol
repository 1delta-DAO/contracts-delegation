// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract WooFiQuoter {
    address internal constant WOO_ROUTER = 0x4c4AF8DBc524681930a27b2F1Af5bcC8062E6fB7;

    /**
     * @notice Calculates amountOut for WooFi swaps
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @param currentOffset Current position in the calldata
     * @return amountOut Output amount
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 1              | padding              |
     */
    function _getWooFiAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 currentOffset
    )
        internal
        view
        returns (uint256 amountOut, uint256)
    {
        assembly {
            // selector for querySwap(address,address,uint256)
            mstore(0xB00, 0xe94803f400000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, tokenIn)
            mstore(0xB24, tokenOut)
            mstore(0xB44, amountIn)
            if iszero(staticcall(gas(), WOO_ROUTER, 0xB00, 0x64, 0xB00, 0x20)) { revert(0, 0) }

            amountOut := mload(0xB00)
            currentOffset := add(currentOffset, 21)
        }
        return (amountOut, currentOffset);
    }
}
