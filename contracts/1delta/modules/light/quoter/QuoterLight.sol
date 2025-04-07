// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Masks} from "../../shared/masks/Masks.sol";
import {DexTypeMappings} from "../swappers/dex/DexTypeMappings.sol";
import {V3TypeQuoter} from "./dex/V3TypeQuoter.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";

contract QuoterLight is Masks, V3TypeQuoter, ERC20Selectors {
    error InvalidDexId();
    error InvalidSplitFormat();

    function quote(bytes calldata data) external returns (uint256 amountOut) {
        uint256 amountIn;
        uint256 minimumAmountReceived;
        address tokenIn;
        uint256 currentOffset;
        assembly {
            currentOffset := data.offset
            minimumAmountReceived := calldataload(currentOffset)
            amountIn := shr(128, minimumAmountReceived)
            minimumAmountReceived := and(UINT128_MASK, minimumAmountReceived)
            currentOffset := add(currentOffset, 32)
            let dataStart := calldataload(currentOffset)
            tokenIn := shr(96, dataStart)
            currentOffset := add(20, currentOffset)
        }
        (uint256 amountOut,,) = _quoteSingleSwapSplitOrRoute(amountIn, tokenIn, currentOffset);
        return amountOut;
    }

    function _quoteSingleSwapSplitOrRoute(uint256 amountIn, address tokenIn, uint256 currentOffset)
        internal
        returns (uint256 amountOut, uint256, address)
    {
        uint256 swapMaxIndex;
        uint256 splitsMaxIndex;
        assembly {
            let datas := calldataload(currentOffset)
            swapMaxIndex := shr(248, datas)
            splitsMaxIndex := and(UINT8_MASK, shr(240, datas)) //next byte
            currentOffset := add(currentOffset, 2)
        }

        address nextToken;
        uint256 received;
        if (swapMaxIndex == 0) {
            // Single swap or split swap
            if (splitsMaxIndex == 0) {
                assembly {
                    nextToken := shr(96, calldataload(currentOffset))
                    currentOffset := add(currentOffset, 40) // skip the receiver: 20 + 20
                }

                (amountOut, currentOffset) = _quoteSingleSwap(amountIn, tokenIn, nextToken, currentOffset);
            } else {
                // Split swap
                (amountOut, currentOffset, nextToken) =
                    _quoteSingleSwapOrSplit(amountIn, swapMaxIndex, tokenIn, address(this), currentOffset);
            }
        } else {
            // Multi-hop swap
            (amountOut, currentOffset, nextToken) =
                _quoteMultiHopSplitSwap(amountIn, swapMaxIndex, tokenIn, currentOffset);
        }
        return (amountOut, currentOffset, nextToken);
    }

    function _quoteSingleSwap(uint256 amountIn, address tokenIn, address tokenOut, uint256 currentOffset)
        internal
        returns (uint256 amountOut, uint256)
    {
        uint256 dexTypeId;
        assembly {
            dexTypeId := shr(248, calldataload(currentOffset))
            currentOffset := add(currentOffset, 1)
        }
        if (dexTypeId == DexTypeMappings.UNISWAP_V3_ID) {
            return getV3TypeAmountOut(amountIn, tokenIn, tokenOut, currentOffset);
        } else {
            revert InvalidDexId();
        }
    }

    function _quoteMultiHopSplitSwap(uint256 amountIn, uint256 swapMaxIndex, address tokenIn, uint256 currentOffset)
        internal
        returns (uint256, uint256, address)
    {
        uint256 amount = amountIn;
        address _tokenIn = tokenIn;
        uint256 i;
        while (true) {
            (amount, currentOffset, _tokenIn) = _quoteSingleSwapSplitOrRoute(amount, _tokenIn, currentOffset);
            // loop break condition
            if (i == swapMaxIndex) {
                break;
            } else {
                i++;
            }
        }
        return (amount, currentOffset, _tokenIn);
    }

    /**
     * Ensure that all paths end with the same CCY
     * parallel swaps a->...->b; a->...->b for different dexs
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 0-16           | splits               |
     * | sC     | Variable       | datas                |
     *
     * `splits` looks like follows
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 1              | count                |
     * | 1      | 2*count - 1    | splits               | <- count = 0 means there is no data, otherwise uint16 splits
     *
     * `datas` looks like follows
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 2              | (r,c)                | <- indicates whether the swap is non-simple (further splits or hops)
     * | 2      | 1              | dexId                |
     * | 3      | variable       | params               | <- depends on dexId (fixed for each one)
     * | 3+v    | 2              | (r,c)                |
     * | 4+v    | 1              | dexId                |
     * | ...    | variable       | params               | <- depends on dexId (fixed for each one)
     * | ...    | ...            | ...                  | <- count + 1 times of repeating this pattern
     *
     * returns cumulative output, updated offset and nextToken address
     */
    function _quoteSingleSwapOrSplit(
        uint256 amountIn,
        uint256 splitsMaxIndex,
        address tokenIn,
        address callerAddress, // caller
        uint256 currentOffset
    ) internal returns (uint256, uint256, address) {
        address nextToken;
        // no splits, single swap
        if (splitsMaxIndex == 0) {
            (amountIn, currentOffset, nextToken) = _quoteSingleSwapSplitOrRoute(
                amountIn,
                tokenIn, //
                currentOffset
            );
        } else {
            uint256 splits;
            assembly {
                splits := shr(128, calldataload(currentOffset))
                currentOffset := add(mul(2, splitsMaxIndex), currentOffset)
            }
            uint256 amount;
            uint256 i;
            uint256 swapsLeft = amountIn;
            while (true) {
                uint256 split;
                assembly {
                    switch eq(i, splitsMaxIndex)
                    case 1 {
                        // assign remaing amount to split
                        split := swapsLeft
                    }
                    default {
                        // splits are uint16s as share of uint16.max
                        split :=
                            div(
                                mul(
                                    and(
                                        UINT16_MASK,
                                        shr(sub(112, mul(i, 16)), splits) // read the uin16 in the splits sequence
                                    ),
                                    amountIn //
                                ),
                                UINT16_MASK //
                            )
                    }
                    i := add(i, 1)
                }
                uint256 received;
                // reenter-universal swap
                // can be another split or a multi-path
                (received, currentOffset, nextToken) = _quoteSingleSwapSplitOrRoute(
                    split,
                    tokenIn, //
                    currentOffset
                );

                // increment and decrement
                assembly {
                    amount := add(amount, received)
                }

                // if nothing is left, break
                if (i > splitsMaxIndex) break;

                // otherwise, we decrement the swaps left amount
                assembly {
                    swapsLeft := sub(swapsLeft, split)
                }
            }
            amountIn = amount;
        }
        return (amountIn, currentOffset, nextToken);
    }
}
