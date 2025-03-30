// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {DeltaErrors} from "../../shared/errors/Errors.sol";
import {DexMappings} from "../../shared/swapper/DexMappings.sol";
import {ExoticOffsets} from "../../shared/swapper/ExoticOffsets.sol";
import {V4TypeGeneric} from "./dex/V4Type.sol";
import {V3TypeGeneric} from "./dex/V3Type.sol";
import {V2TypeGeneric} from "./dex/V2Type.sol";
import {WooFiSwapper} from "./dex/WooFi.sol";
import {DodoV2Swapper} from "./dex/DodoV2Swapper.sol";
import {LBSwapper} from "./dex/LBSwapper.sol";
import {GMXSwapper} from "./dex/GMXSwapper.sol";
import {SyncSwapper} from "./dex/SyncSwapper.sol";
import {CurveSwapper} from "./dex/CurveSwapper.sol";
import {BalancerSwapper} from "./dex/BalancerSwapper.sol";

// solhint-disable max-line-length

/**
 * Core logic: Encode swaps as nested matrices (r: rows - multihops; c:columns - splits)
 * Every element in a matrix can be another matrix
 * The nesting stops at a (0,0) entry
 * E.g. a multihop with each hop having 2 splits is identified as
 * (1,0)  <-- 1 as row implicates a multihop of length 2 (max index is 1)                 
 *      \
 *      (0,1)  --------------- (0,1)   <- the 1s in the columns indicate that  
 *        |                      |        there are 2 splits in each sub step
 *        ├(0,0)**               ├(0,0)
 *        |                      | 
 *        ├(1,0)                 ├(0,0)  <- the (0,0) entries indicate an atomic swap (e.g. a uni V2 swap)
 *           \
 *          (0,0)  --- (0,0)  <- this is a branching multihip within a split (indicated by (1,0)
 *                               the output token is expected to be the same as for the 
 *                               prior split in **
 * 
 * The logic accumulates values per column to enable consistent multihops without additional balance reads
 * 
 * Multihops progressively update value (in amount -> out amount) too always ensure that values 
 * within sub splits ((x,0) or (0,y)) are correctly accumulated
 * 
 * A case like (1,2) is a violation as we always demand a clear gruping of the branch
 * This is intuitive as we cannot have a split and a multihop at the same time. 
 * 
 * Every node with (x,0) is expected to have consistent multihop connections
 * 
 * Every node with (0,y) is expected to have sub nodes and path that have all the same output currency
 *
 * Swap execution is always along rows then columns
 * In the example above, we indicate a multihop
 * Each hop has length 0 (single swap) but 1 split
 * Each split is a single swap (0,0)
 * 
 * This allows arbitrary deep nesting of sub-routes and splits
 * 
 * Rows are prioritized over columns.
 * /

/**
 * @title Base swapper contract
 * @notice Contains basic logic for swap executions with DEXs
 * DEX Id layout:
 * 0 --- 100 : Self swappers (Uni V3, Curve, Clipper)
 * 100 - 255 : Funded swaps (Uni V2, Solidly, Moe,Joe LB, WooFI, GMX)
 *             Uni V2: 100 - 110
 *             Solidly:121 - 130
 */
abstract contract BaseSwapper is
    V4TypeGeneric,
    V3TypeGeneric,
    V2TypeGeneric,
    DexMappings,
    ExoticOffsets,
    BalancerSwapper,
    LBSwapper,
    DodoV2Swapper,
    WooFiSwapper,
    CurveSwapper,
    GMXSwapper, //
    SyncSwapper,
    DeltaErrors
{
    /*
     * multihop swapper that allows for splits in each hops
     * forward the amountOut received from the last hop
     */
    function _multihopSplitSwap(
        uint256 amountIn,
        uint256 swapMaxIndex,
        address tokenIn,
        address callerAddress,
        uint256 currentOffset //
    ) internal returns (uint256, uint256, address) {
        uint256 amount = amountIn;
        address _tokenIn = tokenIn;
        uint256 i;
        while (true) {
            (amount, currentOffset, _tokenIn) = _singleSwapSplitOrRoute(
                amount,
                _tokenIn,
                callerAddress,
                currentOffset //
            );
            // break criteria
            if (i == swapMaxIndex) {
                break;
            } else {
                // update context
                assembly {
                    i := add(i, 1)
                }
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
    function _singleSwapOrSplit(
        uint256 amountIn,
        uint256 splitsMaxIndex,
        address tokenIn,
        address callerAddress, // caller
        uint256 currentOffset
    ) internal returns (uint256, uint256, address) {
        address nextToken;
        // no splits, single swap
        if (splitsMaxIndex == 0) {
            (amountIn, currentOffset, nextToken) = _singleSwapSplitOrRoute(
                amountIn,
                tokenIn, //
                callerAddress,
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
                        split := div(
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
                (received, currentOffset, nextToken) = _singleSwapSplitOrRoute(
                    split,
                    tokenIn, //
                    callerAddress,
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

    /*
     * execute swap or split amounts
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 2              | (r,c)                |
     * | 2      | 20             | nextToken            |
     * | 22     | any            | swapData             |
     *
     * if r=0
     *      if c=0 : single swap
     *      else: split swap
     * else: multihop swap
     *
     * always return output amount, updated offset and nextToken address
     */
    function _singleSwapSplitOrRoute(
        uint256 amountIn,
        address tokenIn,
        address callerAddress,
        uint256 currentOffset //
    ) internal returns (uint256, uint256, address) {
        uint256 swapMaxIndex;
        uint256 splitsMaxIndex;
        assembly {
            let datas := calldataload(currentOffset)
            swapMaxIndex := shr(248, datas)
            splitsMaxIndex := and(UINT8_MASK, shr(240, datas))
            currentOffset := add(currentOffset, 2)
        }
        // swapMaxIndex = 0 is simple single swap
        // that is where each single step MUST end
        address nextToken;
        uint256 received;
        if (swapMaxIndex == 0) {
            // splitsMaxIndex zero is single swap
            if (splitsMaxIndex == 0) {
                // if the swapMaxIndex is single-swap,
                // the next two addresses are nextToken and receiver
                address receiver;
                assembly {
                    nextToken := shr(96, calldataload(currentOffset))
                    currentOffset := add(currentOffset, 20)
                    receiver := shr(96, calldataload(currentOffset))
                    currentOffset := add(currentOffset, 20)
                }
                (received, currentOffset) = _swapExactInSimple(
                    amountIn,
                    tokenIn,
                    nextToken,
                    callerAddress,
                    receiver, //
                    currentOffset
                );
            } else {
                // nonzero is a split swap
                (received, currentOffset, nextToken) = _singleSwapOrSplit(
                    amountIn,
                    splitsMaxIndex,
                    tokenIn,
                    callerAddress,
                    currentOffset //
                );
            }
        } else {
            // otherwise, execute universal swap (path & splits)
            (received, currentOffset, nextToken) = _multihopSplitSwap(
                amountIn, //
                swapMaxIndex,
                tokenIn,
                callerAddress,
                currentOffset
            );
        }
        return (received, currentOffset, nextToken);
    }

    /**
     * Swaps exact in internally using all implemented Dexs
     * Will NOT use a flash swap
     * The dexId is assumed to be fetched before in a prefunding action
     * As such, the parameter can be plugged in here directly
     * @param amountIn sell amount
     * @return (amountOut, new offset) buy amount
     */
    function _swapExactInSimple(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address payer, // first step
        address receiver, // last step
        uint256 currentOffset
    ) internal returns (uint256, uint256) {
        uint256 dexId;
        assembly {
            dexId := shr(248, calldataload(currentOffset))
            currentOffset := add(currentOffset, 1)
        }
        ////////////////////////////////////////////////////
        // We switch-case through the different pool types
        // To select the correct pool for the swap action
        ////////////////////////////////////////////////////

        // uniswapV3 style
        if (dexId < UNISWAP_V3_MAX_ID) {
            (amountIn, currentOffset) = _swapUniswapV3PoolExactInGeneric(
                dexId,
                amountIn,
                tokenIn,
                tokenOut,
                receiver,
                currentOffset,
                payer //
            );
        }
        // iZi
        else if (dexId == IZI_ID) {
            (amountIn, currentOffset) = _swapIZIPoolExactInGeneric(
                dexId,
                amountIn,
                tokenIn,
                tokenOut,
                receiver,
                currentOffset,
                payer //
            );
        }
        // uni V4
        else if (dexId == UNISWAP_V4_ID) {
            (amountIn, currentOffset) = _swapUniswapV4ExactInGeneric(
                amountIn,
                tokenIn,
                tokenOut,
                receiver,
                currentOffset,
                payer //
            );
        }
        // Balancer V2s
        else if (dexId == BALANCER_V2_ID) {
            (amountIn, currentOffset) = _swapBalancerExactIn(
                tokenIn,
                tokenOut,
                amountIn,
                receiver, //
                payer,
                currentOffset
            );
        }
        // Curve pool types
        else if (dexId < CURVE_V1_MAX_ID) {
            // Curve standard pool
            if (dexId == CURVE_V1_STANDARD_ID) {
                (amountIn, currentOffset) = _swapCurveGeneral(
                    tokenIn,
                    tokenOut,
                    amountIn,
                    receiver, //
                    payer,
                    currentOffset
                );
            } else if (dexId == CURVE_FORK_ID) {
                (amountIn, currentOffset) = _swapCurveFork(
                    tokenIn,
                    tokenOut,
                    amountIn,
                    receiver, //
                    payer,
                    currentOffset
                );
            } else {
                assembly {
                    mstore(0, INVALID_DEX)
                    revert(0, 0x4)
                }
            }
        }
        // uniswapV2 style
        else if (dexId < UNISWAP_V2_MAX_ID) {
            (amountIn, currentOffset) = _swapUniswapV2PoolExactInGeneric(
                dexId,
                amountIn,
                tokenIn,
                tokenOut,
                receiver,
                currentOffset,
                payer //
            );
        }
        // WOO Fi
        else if (dexId == WOO_FI_ID) {
            (amountIn, currentOffset) = _swapWooFiExactIn(
                amountIn,
                tokenIn,
                tokenOut,
                receiver,
                payer, //
                currentOffset
            );
        }
        // Curve NG
        else if (dexId == CURVE_RECEIVED_ID) {
            (amountIn, currentOffset) = _swapCurveReceived(
                tokenIn,
                amountIn,
                receiver, //
                payer,
                currentOffset
            );
        }
        // GMX
        else if (dexId < MAX_GMX_ID) {
            (amountIn, currentOffset) = _swapGMXExactIn(
                amountIn,
                tokenIn,
                tokenOut,
                receiver,
                payer, //
                currentOffset
            );
        }
        // syncSwap style
        else if (dexId == SYNC_SWAP_ID) {
            (amountIn, currentOffset) = _swapSyncExactIn(
                amountIn,
                tokenIn,
                receiver,
                payer, //
                currentOffset
            );
        }
        // DODO V2
        else if (dexId == DODO_ID) {
            (amountIn, currentOffset) = _swapDodoV2ExactIn(
                amountIn,
                tokenIn,
                receiver,
                payer, //
                currentOffset
            );
        }
        // Moe LB
        else if (dexId == LB_ID) {
            (amountIn, currentOffset) = _swapLBexactIn(
                amountIn,
                tokenIn,
                tokenOut,
                receiver,
                payer, //
                currentOffset
            );
        } else if (dexId == NATIVE_WRAP_ID) {
            (amountIn, currentOffset) = _wrapOrUnwrapSimple(
                amountIn,
                currentOffset //
            );
        } else {
            assembly {
                mstore(0, INVALID_DEX)
                revert(0, 0x4)
            }
        }
        return (amountIn, currentOffset);
    }

    function _wrapOrUnwrapSimple(uint256 amount, uint256 currentOffset) internal virtual returns (uint256, uint256) {}
}
