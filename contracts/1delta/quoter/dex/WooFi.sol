// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract WooFiQuoter {
    address internal constant WOO_ROUTER = 0x4c4AF8DBc524681930a27b2F1Af5bcC8062E6fB7;

    function getWooFiAmountOut(address tokenIn, address tokenOut, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            // selector for querySwap(address,address,uint256)
            mstore(0xB00, 0xe94803f400000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, tokenIn)
            mstore(0xB24, tokenOut)
            mstore(0xB44, amountIn)
            if iszero(staticcall(gas(), WOO_ROUTER, 0xB00, 0x64, 0xB00, 0x20)) {
                revert(0, 0)
            }

            amountOut := mload(0xB00)
        }
    }
}
