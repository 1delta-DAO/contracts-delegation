// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract SyncQuoter {
    function quoteSyncSwapExactIn(address pair, address tokenIn, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            // selector for getAmountOut(address,uint256,address)
            mstore(ptr, 0xff9c8ac600000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), tokenIn)
            mstore(add(ptr, 0x24), amountIn)
            mstore(add(ptr, 0x44), 0x0)
            if iszero(staticcall(gas(), pair, ptr, 0x64, ptr, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            amountOut := mload(ptr)
        }
    }
}
