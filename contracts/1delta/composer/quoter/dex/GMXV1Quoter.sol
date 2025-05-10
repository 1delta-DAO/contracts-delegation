// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract GMXQuoter {
    /**
     * Swaps exact input on GMX V1
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     */
    function _getGMXAmountOut(
        address _tokenIn,
        address _tokenOut,
        uint256 amountIn,
        address receiverIsReader,
        uint256 currentOffset
    )
        internal
        view
        returns (uint256 amountOut, uint256)
    {
        assembly {
            let ptr := mload(0x40)
            let vault := shr(96, calldataload(currentOffset))
            // getAmountOut(address,address,address,uint256)
            mstore(ptr, 0xd7176ca900000000000000000000000000000000000000000000000000000000)
            // get maxPrice
            mstore(add(ptr, 0x4), vault) // vault
            mstore(add(ptr, 0x24), _tokenIn)
            mstore(add(ptr, 0x44), _tokenOut)
            mstore(add(ptr, 0x64), amountIn)
            pop(
                staticcall(
                    gas(),
                    receiverIsReader, // this goes to the oracle
                    ptr,
                    0x84,
                    0x0, // do NOT override the selector
                    0x20
                )
            )
            amountOut := mload(0x0)
            currentOffset := add(currentOffset, 21) // skip pool plus flag
        }
        return (amountOut, currentOffset);
    }
}
