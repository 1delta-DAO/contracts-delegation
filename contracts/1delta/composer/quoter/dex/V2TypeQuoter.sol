// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../../shared/masks/Masks.sol";

abstract contract V2TypeQuoter is ERC20Selectors, Masks {
    /*
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 2              | feeDenom             |
     * | 22     | 1              | forkId               |
     * | 23     | 2              | calldataLength       | <-- 0: pay from self; 1: caller pays; 3: pre-funded;
     * | 25     | calldataLength | calldata             |
     */
    /// @dev calculate amountOut for uniV2 style pools - does not require overflow checks
    function _getV2TypeAmountOut(
        uint256 sellAmount,
        address tokenIn,
        address tokenOut,
        uint256 currentOffset
    )
        internal
        view
        returns (uint256, uint256)
    {
        uint256 buyAmount;
        uint256 clLength;
        assembly {
            // Compute the buy amount based on the pair reserves.
            let pair := calldataload(currentOffset)
            clLength := and(UINT16_MASK, shr(56, pair))

            {
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                switch lt(and(UINT8_MASK, shr(72, pair)), 128)
                case 1 {
                    let feeDenom := and(shr(80, pair), UINT16_MASK)
                    pair := shr(96, pair)
                    // Call pair.getReserves(), store the results at `0xC00`
                    mstore(0xB00, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
                    if iszero(staticcall(gas(), pair, 0xB00, 0x4, 0xC00, 0x40)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    // Revert if the pair contract does not return at least two words.
                    if lt(returndatasize(), 0x40) { revert(0, 0) }

                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0xC00)
                        buyReserve := mload(0xC20)
                    }
                    default {
                        sellReserve := mload(0xC20)
                        buyReserve := mload(0xC00)
                    }
                    let sellAmountWithFee := mul(sellAmount, feeDenom)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 10000)))
                }
                // covers solidly: velo volatile, stable and cleo V1 volatile, stable, stratum volatile, stable
                default {
                    pair := shr(96, pair)
                    // selector for getAmountOut(uint256,address)
                    mstore(0xB00, 0xf140a35a00000000000000000000000000000000000000000000000000000000)
                    mstore(0xB04, sellAmount)
                    mstore(0xB24, tokenIn)
                    if iszero(staticcall(gas(), pair, 0xB00, 0x44, 0xB00, 0x20)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    buyAmount := mload(0xB00)
                }
            }
        }
        return (buyAmount, currentOffset + 25 + clLength);
    }
}
