// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

// solhint-disable max-line-length

abstract contract SyncQuoter {
    function _quoteSyncSwapExactIn(address tokenIn, uint256 amountIn, uint256 currentOffset) internal view returns (uint256 amountOut, uint256) {
        assembly {
            let syncSwapData := calldataload(currentOffset)
            let pool := shr(96, syncSwapData)

            let ptr := mload(0x40)
            // selector for getAmountOut(address,uint256,address)
            mstore(ptr, 0xff9c8ac600000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), tokenIn)
            mstore(add(ptr, 0x24), amountIn)
            mstore(add(ptr, 0x44), 0x0)
            if iszero(staticcall(gas(), pool, ptr, 0x64, ptr, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            currentOffset := add(currentOffset, 21)

            amountOut := mload(ptr)
        }
        return (amountOut, currentOffset);
    }
}
