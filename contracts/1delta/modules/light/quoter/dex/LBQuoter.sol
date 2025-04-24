// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";

abstract contract LBQuoter is Masks {
    function _getLBAmountOut(
        uint256 amountIn,
        uint256 currentOffset //
    )
        internal
        view
        returns (uint256 amountOut, uint256 lbDataThenOffset)
    {
        assembly {
            let ptr := mload(0x40)
            lbDataThenOffset := calldataload(currentOffset)
            let swapForY := and(UINT8_MASK, shr(88, lbDataThenOffset))
            lbDataThenOffset := shr(96, lbDataThenOffset)

            // getSwapOut(uint128,bool)
            mstore(ptr, 0xe77366f800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), amountIn)
            mstore(add(ptr, 0x24), swapForY)
            // call swap simulator, revert if invalid/undefined pair
            if iszero(staticcall(gas(), lbDataThenOffset, ptr, 0x44, ptr, 0x40)) { revert(0, 0) }
            amountOut :=
                and(
                    0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff, // mask uint128
                    mload(add(ptr, 0x20))
                )
            // the first slot returns amount in left, if positive, we revert
            if gt(mload(ptr), 0) { revert(0, 0) }
            lbDataThenOffset := add(currentOffset, 22)
        }

        return (amountOut, lbDataThenOffset);
    }
}
