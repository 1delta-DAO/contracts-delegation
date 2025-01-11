// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract LBQuoter {
    function getLBAmountOut(
        address tokenOut,
        uint256 amountIn,
        address pair // identifies the exact pair address
    ) internal view returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            // getTokenY()
            mstore(ptr, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            if iszero(
                // invalid pairs will make it fail here
                staticcall(gas(), pair, ptr, 0x4, ptr, 0x20)
            ) {
                revert(0, 0)
            }
            // override swapForY
            let swapForY := eq(tokenOut, mload(ptr))
            // getSwapOut(uint128,bool)
            mstore(ptr, 0xe77366f800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), amountIn)
            mstore(add(ptr, 0x24), swapForY)
            // call swap simulator, revert if invalid/undefined pair
            if iszero(staticcall(gas(), pair, ptr, 0x44, ptr, 0x40)) {
                revert(0, 0)
            }
            amountOut := and(
                0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff, // mask uint128
                mload(add(ptr, 0x20))
            )
            // the first slot returns amount in left, if positive, we revert
            if gt(mload(ptr), 0) {
                revert(0, 0)
            }
        }
    }

    function getLBAmountIn(
        address tokenOut,
        uint256 amountOut,
        address pair // this param identifies the pair
    ) internal view returns (uint256 amountIn) {
        assembly {
            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(0x4, pair)

            // call to underlying
            if iszero(staticcall(gas(), tokenOut, 0x0, 0x24, 0x0, 0x20)) {
                revert(0, 0)
            }
            // pair must have enough liquidity
            if lt(mload(0x0), amountOut) {
                revert(0, 0)
            }

            let ptr := mload(0x40)
            // getTokenY()
            mstore(ptr, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            pop(
                // the call will always succeed due to the pair being nonzero
                staticcall(gas(), pair, ptr, 0x4, ptr, 0x20)
            )
            // override swapForY
            let swapForY := eq(tokenOut, mload(ptr))
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
            if gt(mload(add(ptr, 0x20)), 0) {
                revert(0, 0)
            }
        }
    }
}
