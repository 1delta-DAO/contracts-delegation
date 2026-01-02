// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Masks} from "../../shared/masks/Masks.sol";
import {DexTypeMappings} from "../swappers/dex/DexTypeMappings.sol";
import {V4TypeQuoter} from "./dex/V4TypeQuoter.sol";
import {V3TypeQuoter} from "./dex/V3TypeQuoter.sol";
import {BalancerV3Quoter} from "./dex/BalancerV3Quoter.sol";
import {V2TypeQuoter} from "./dex/V2TypeQuoter.sol";
import {CurveQuoter} from "./dex/CurveQuoter.sol";
import {WooFiQuoter} from "./dex/WooFiQuoter.sol";
import {SyncQuoter} from "./dex/SyncQuoter.sol";
import {DodoV2Quoter} from "./dex/DodoV2Quoter.sol";
import {LBQuoter} from "./dex/LBQuoter.sol";
import {KTXQuoter} from "./dex/KTXQuoter.sol";
import {GMXQuoter} from "./dex/GMXV1Quoter.sol";
import {BalancerV2Quoter} from "./dex/BalancerV2Quoter.sol";
import {WrapperQuoter} from "./dex/WrapperQuoter.sol";

// solhint-disable max-line-length

contract QuoterLight is
    WrapperQuoter,
    BalancerV3Quoter,
    V4TypeQuoter,
    V3TypeQuoter,
    V2TypeQuoter,
    DodoV2Quoter,
    CurveQuoter,
    WooFiQuoter,
    SyncQuoter,
    LBQuoter,
    GMXQuoter,
    KTXQuoter,
    BalancerV2Quoter //
{
    error InvalidDexId();

    function quote(uint256 amountIn, bytes calldata data) external returns (uint256 amountOut) {
        address tokenIn;
        uint256 currentOffset;
        assembly {
            currentOffset := data.offset
            let dataStart := calldataload(currentOffset)
            tokenIn := shr(96, dataStart)
            currentOffset := add(20, currentOffset)
        }
        (amountOut,,) = _quoteSingleSwapSplitOrRoute(amountIn, tokenIn, currentOffset);
    }

    function _quoteSingleSwapSplitOrRoute(
        uint256 amountIn,
        address tokenIn,
        uint256 currentOffset
    )
        internal
        returns (uint256 amountOut, uint256, address nextToken)
    {
        uint256 swapMaxIndex;
        uint256 splitsMaxIndex;
        assembly {
            let datas := calldataload(currentOffset)
            swapMaxIndex := shr(248, datas)
            splitsMaxIndex := and(UINT8_MASK, shr(240, datas)) //next byte
            currentOffset := add(currentOffset, 2)
        }

        if (swapMaxIndex == 0) {
            // Single swap or split swap
            if (splitsMaxIndex == 0) {
                /**
                 * Some Dexs ue the receiver param as an additional parameter
                 * that is not used for swapping, only for quoting
                 */
                address receiverParam;
                assembly {
                    nextToken := shr(96, calldataload(currentOffset))
                    receiverParam := shr(96, calldataload(add(currentOffset, 20)))
                    currentOffset := add(currentOffset, 40) // skip the receiverParam: 20 + 20
                }

                (amountOut, currentOffset) = _quoteSingleSwap(amountIn, tokenIn, nextToken, receiverParam, currentOffset);
            } else {
                // Split swap
                (amountOut, currentOffset, nextToken) = _quoteSingleSwapOrSplit(
                    amountIn,
                    splitsMaxIndex, //
                    tokenIn,
                    currentOffset
                );
            }
        } else {
            // Multi-hop swap
            (amountOut, currentOffset, nextToken) = _quoteMultiHopSplitSwap(
                amountIn, //
                swapMaxIndex,
                tokenIn,
                currentOffset
            );
        }
        return (amountOut, currentOffset, nextToken);
    }

    /**
     * We use the `receiver` as an additional addres needed for quoting
     * for DEXs like GMX and KTX
     */
    function _quoteSingleSwap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address receiverParam,
        uint256 currentOffset
    )
        internal
        returns (uint256 amountOut, uint256)
    {
        uint256 dexTypeId;
        assembly {
            dexTypeId := shr(248, calldataload(currentOffset))
            currentOffset := add(currentOffset, 1)
        }
        // uniswapV3 style
        if (dexTypeId == DexTypeMappings.UNISWAP_V3_ID) {
            return _getV3TypeAmountOut(amountIn, tokenIn, tokenOut, currentOffset);
        }
        // uniswapV4 style
        else if (dexTypeId == DexTypeMappings.UNISWAP_V4_ID) {
            return _getV4TypeAmountOut(amountIn, tokenIn, tokenOut, currentOffset);
        }
        // balancer V3 style
        else if (dexTypeId == DexTypeMappings.BALANCER_V3_ID) {
            return _getBalancerV3TypeAmountOut(amountIn, tokenIn, tokenOut, currentOffset);
        }
        // uniswapV3 style
        else if (dexTypeId == DexTypeMappings.IZI_ID) {
            return _getIzumiAmountOut(amountIn, tokenIn, tokenOut, currentOffset);
        }
        // uniswapV2 style
        else if (dexTypeId == DexTypeMappings.UNISWAP_V2_ID) {
            return _getV2TypeAmountOut(amountIn, tokenIn, tokenOut, currentOffset);
        }
        // wooFi style
        else if (dexTypeId == DexTypeMappings.WOO_FI_ID) {
            return _getWooFiAmountOut(tokenIn, tokenOut, amountIn, currentOffset);
        }
        // balancerV2 style
        else if (dexTypeId == DexTypeMappings.BALANCER_V2_ID) {
            return _getBalancerAmountOut(tokenIn, tokenOut, amountIn, currentOffset);
        }
        // curve style
        else if (
            dexTypeId == DexTypeMappings.CURVE_V1_STANDARD_ID || dexTypeId == DexTypeMappings.CURVE_FORK_ID //
                || dexTypeId == DexTypeMappings.CURVE_RECEIVED_ID
        ) {
            return _getCurveAmountOut(amountIn, currentOffset);
        }
        // dodoV2 style
        else if (dexTypeId == DexTypeMappings.DODO_ID) {
            return _getDodoV2AmountOut(amountIn, currentOffset);
        }
        // GMX style
        else if (dexTypeId == DexTypeMappings.GMX_ID) {
            /**
             * Receiver param = GMX reader contract
             */
            return _getGMXAmountOut(tokenIn, tokenOut, amountIn, receiverParam, currentOffset);
        }
        // KTX style
        else if (dexTypeId == DexTypeMappings.KTX_ID) {
            /**
             * Receiver param = KTX vault utils contract
             */
            return _getKTXAmountOut(tokenIn, tokenOut, amountIn, receiverParam, currentOffset);
        }
        // LB style
        else if (dexTypeId == DexTypeMappings.LB_ID) {
            return _getLBAmountOut(amountIn, currentOffset);
        }
        // sync swap style
        else if (dexTypeId == DexTypeMappings.SYNC_SWAP_ID) {
            return _quoteSyncSwapExactIn(tokenIn, amountIn, currentOffset);
        } else if (dexTypeId == DexTypeMappings.ASSET_WRAP_ID) {
            return _quoteWrapperExactIn(tokenIn, tokenOut, amountIn, currentOffset);
        } else {
            revert InvalidDexId();
        }
    }

    function _quoteMultiHopSplitSwap(
        uint256 amountIn,
        uint256 swapMaxIndex,
        address tokenIn,
        uint256 currentOffset
    )
        internal
        returns (uint256 amount, uint256, address _tokenIn)
    {
        amount = amountIn;
        _tokenIn = tokenIn;
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
     * @notice Ensures that all paths end with the same currency
     * @dev Parallel swaps a->...->b; a->...->b for different DEXs
     * @param amountIn Input amount
     * @param splitsMaxIndex Maximum split index
     * @param tokenIn Input token address
     * @param currentOffset Current position in the calldata
     * @return Updated amount after quotes
     * @return Updated calldata offset after processing
     * @return nextToken Next token address
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 0-16           | splits               |
     * | sC     | Variable       | datas                |
     *
     * @custom:split-format
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 1              | count                |
     * | 1      | 2*count - 1    | splits               | <- count = 0 means there is no data, otherwise uint16 splits
     *
     * @custom:datas-format
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 2              | (r,c)                | <- indicates whether the swap is non-simple (further splits or hops)
     * | 2      | 1              | dexId                |
     * | 3      | variable       | params               | <- depends on dexId (fixed for each one)
     * | 3+v    | 2              | (r,c)                |
     * | 4+v    | 1              | dexId                |
     * | ...    | variable       | params               | <- depends on dexId (fixed for each one)
     * | ...    | ...            | ...                  | <- count + 1 times of repeating this pattern
     */
    function _quoteSingleSwapOrSplit(
        uint256 amountIn,
        uint256 splitsMaxIndex,
        address tokenIn,
        uint256 currentOffset
    )
        internal
        returns (uint256, uint256, address)
    {
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
