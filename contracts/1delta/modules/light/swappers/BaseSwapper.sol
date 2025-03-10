// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {DeltaErrors} from "../../shared/errors/Errors.sol";
import {DexMappings} from "../../shared/swapper/DexMappings.sol";
import {ExoticOffsets} from "../../shared/swapper/ExoticOffsets.sol";
import {UnoSwapper} from "../../shared/swapper/UnoSwapper.sol";
import {GMXSwapper} from "../../shared/swapper/GMXSwapper.sol";
import {LBSwapper} from "../../shared/swapper/LBSwapper.sol";
import {DodoV2Swapper} from "../../shared/swapper/DodoV2Swapper.sol";
import {BalancerSwapper} from "../../shared/swapper/BalancerSwapper.sol";
import {V3TypeGeneric} from "./V3Type.sol";
import {console} from "forge-std/console.sol";

// solhint-disable max-line-length

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
    V3TypeGeneric,
    DexMappings,
    ExoticOffsets,
    UnoSwapper,
    BalancerSwapper,
    LBSwapper,
    DodoV2Swapper,
    GMXSwapper, //
    DeltaErrors
{
    /**
     * Swaps exact in internally specifically for FOT tokens (uni V2 type only)
     * Will work with nnormal tokens, too, however, it is slightly less efficient
     * Will also never use a flash swap
     * The dexId is assumed to be fetched before in a prefunding action
     * @param amountIn sell amount
     * @return amountOut buy amount
     */
    function swapExactInSimpleFOT(
        uint256 amountIn,
        address receiver, // last step
        uint256 pathOffset,
        uint256 pathLength
    ) internal returns (uint256, uint256) {
        amountIn = swapUniV2ExactInFOT(amountIn, receiver, pathOffset);
        assembly {
            pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
            pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
        }
        ////////////////////////////////////////////////////
        // From there on, we just continue to swap if needed
        // similar to conventional swaps
        ////////////////////////////////////////////////////
        return (amountIn, pathOffset);
    }

    /**
     * parallel swaps a->b; a->b for different dexs
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 1              | splitsCount          |
     * | 1      | 0-16           | splits               |
     * | 17     | 20             | tokenIn              |
     * | 37     | 20             | tokenOut             |
     * | 57     | 20             | receiver             |
     * | 77     | 20             | datas                |
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
     * | 0      | 1              | dexId                |
     * | 1      | variable       | params               | <- depends on dexId (fixed for each one)
     * | 1+v    | 1              | dexId                |
     * | 2+v    | variable       | params               | <- depends on dexId (fixed for each one)
     * | ...    | ...            | ...                  | <- count + 1 times of repeating this pattern
     */
    function _eSwapExactIn(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address payer, // first step
        address receiver, // last step
        uint256 currentOffset
    ) internal returns (uint256, uint256) {
        uint256 splits;
        uint256 splitsCount;
        assembly {
            splits := calldataload(currentOffset)
            splitsCount := shr(248, splits)
            currentOffset := add(1, currentOffset)
        }
        console.log("tokenIn", tokenIn);
        console.log("tokenOut", tokenOut);
        console.log("splitsCount", splitsCount);
        // muliplts splits
        if (splitsCount != 0) {
            assembly {
                splits := shr(136, splits)
                currentOffset := add(mul(2, splits), currentOffset)
            }
            uint256 amount;
            uint256 i;
            uint256 swapsLeft = amountIn;
            while (true) {
                uint256 received;
                uint256 split;
                assembly {
                    split := div(
                        mul(
                            shr(mul(i, 16), splits),
                            amountIn //
                        ),
                        UINT16_MASK //
                    )
                    i := add(i, 1)
                    if iszero(split) {
                        split := sub(amountIn, swapsLeft)
                    }
                }
                (received, currentOffset) = swapExactInSimple2(
                    split,
                    tokenIn,
                    tokenOut,
                    payer,
                    receiver, //
                    currentOffset
                );

                // increment and decrement
                swapsLeft -= split;
                amount += received;

                // if nothing is left, break
                if (i == splitsCount) break;
            }
            amountIn = amount;
        } else {
            console.log("tokenIn, tokenOut", tokenIn, tokenOut);
            (amountIn, currentOffset) = swapExactInSimple2(
                amountIn,
                tokenIn,
                tokenOut,
                payer,
                receiver, //
                currentOffset
            );
        }
        return (amountIn, currentOffset);
    }

    /**
     * Swaps exact in internally using all implemented Dexs
     * Will NOT use a flash swap
     * The dexId is assumed to be fetched before in a prefunding action
     * As such, the parameter can be plugged in here directly
     * @param amountIn sell amount
     * @param dexId dex identifier
     * @return (amountOut, new offset) buy amount
     */
    function swapExactInSimple(
        uint256 amountIn,
        uint256 dexId,
        address payer, // first step
        address receiver, // last step
        uint256 pathOffset
    ) internal returns (uint256, uint256) {
        ////////////////////////////////////////////////////
        // We switch-case through the different pool types
        // To select the correct pool for the swap action
        // Note that this is auto-forwarding the amountIn,
        // as such, this is dynamically usable within
        // flash-swaps.
        // Note that `dexId` gets reassigned within each
        // execution step if we are not yet at the final pool
        ////////////////////////////////////////////////////
        // uniswapV3 style
        if (dexId < UNISWAP_V3_MAX_ID) {
            amountIn = _swapUniswapV3PoolExactIn(
                amountIn,
                0,
                payer,
                receiver,
                pathOffset,
                64 // we do not need end flags
            );
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
            }
        }
        // iZi
        else if (dexId == IZI_ID) {
            amountIn = _swapIZIPoolExactIn(uint128(amountIn), 0, payer, receiver, pathOffset, 64);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
            }
        }
        // Balancer V2
        else if (dexId == BALANCER_V2_ID) {
            amountIn = _swapBalancerExactIn(payer, amountIn, receiver, pathOffset);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_BALANCER_V2)
            }
        }
        // Curve pool types
        else if (dexId < CURVE_V1_MAX_ID) {
            // Curve standard pool
            if (dexId == CURVE_V1_STANDARD_ID) {
                amountIn = _swapCurveGeneral(pathOffset, amountIn, payer, receiver);
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_CURVE)
                }
            } else {
                assembly {
                    mstore(0, INVALID_DEX)
                    revert(0, 0x4)
                }
            }
        }
        // uniswapV2 style
        else if (dexId < UNISWAP_V2_MAX_ID) {
            amountIn = swapUniV2ExactInComplete(
                amountIn,
                0,
                payer,
                receiver,
                false,
                pathOffset, // we do not slice the path since we deterministically prevent flash swaps
                0
            );
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
            }
        }
        // WOO Fi
        else if (dexId == WOO_FI_ID) {
            address tokenIn;
            address tokenOut;
            address pool;
            assembly {
                tokenIn := shr(96, calldataload(pathOffset))
                tokenOut := shr(96, calldataload(add(pathOffset, 42)))
                pool := shr(96, calldataload(add(pathOffset, 22)))
            }
            // amountIn = swapWooFiExactIn(tokenIn, tokenOut, pool, amountIn, receiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_ADDRESS)
            }
        }
        // Curve NG
        else if (dexId == CURVE_RECEIVED_ID) {
            amountIn = _swapCurveReceived(pathOffset, amountIn, receiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_CURVE)
            }
        }
        // GMX
        else if (dexId == GMX_ID || dexId == KTX_ID) {
            address tokenIn;
            address tokenOut;
            address vault;
            assembly {
                tokenIn := shr(96, calldataload(pathOffset))
                tokenOut := shr(96, calldataload(add(pathOffset, 42)))
                vault := shr(96, calldataload(add(pathOffset, 22)))
            }
            amountIn = swapGMXExactIn(tokenIn, tokenOut, vault, receiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_ADDRESS)
            }
        }
        // DODO V2
        else if (dexId == DODO_ID) {
            address pair;
            uint8 sellQuote;
            assembly {
                let params := calldataload(add(pathOffset, 11))
                pair := shr(8, params)
                sellQuote := and(UINT8_MASK, params)
            }
            amountIn = swapDodoV2ExactIn(sellQuote, pair, receiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_ADDRESS_AND_PARAM)
            }
        }
        // Moe LB
        else if (dexId == LB_ID) {
            address tokenIn;
            address tokenOut;
            address pair;
            assembly {
                tokenIn := shr(96, calldataload(pathOffset))
                tokenOut := shr(96, calldataload(add(pathOffset, 42)))
                pair := shr(96, calldataload(add(pathOffset, 22)))
            }
            amountIn = swapLBexactIn(tokenOut, pair, receiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_ADDRESS)
            }
        } else {
            assembly {
                mstore(0, INVALID_DEX)
                revert(0, 0x4)
            }
        }
        return (amountIn, pathOffset);
    }

    /**
     * Swaps exact in internally using all implemented Dexs
     * Will NOT use a flash swap
     * The dexId is assumed to be fetched before in a prefunding action
     * As such, the parameter can be plugged in here directly
     * @param amountIn sell amount
     * @return (amountOut, new offset) buy amount
     */
    function swapExactInSimple2(
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
        console.log("dexId", dexId);
        ////////////////////////////////////////////////////
        // We switch-case through the different pool types
        // To select the correct pool for the swap action
        // Note that this is auto-forwarding the amountIn,
        // as such, this is dynamically usable within
        // flash-swaps.
        // Note that `dexId` gets reassigned within each
        // execution step if we are not yet at the final pool
        ////////////////////////////////////////////////////
        // uniswapV3 style
        if (dexId < UNISWAP_V3_MAX_ID) {
            (amountIn, ) = _swapUniswapV3PoolExactInGeneric(
                dexId,
                amountIn,
                tokenIn,
                tokenOut,
                receiver,
                currentOffset,
                payer // we do not need end flags
            );
            assembly {
                currentOffset := add(currentOffset, SKIP_LENGTH_UNOSWAP)
            }
        }
        // iZi
        else if (dexId == IZI_ID) {
            amountIn = _swapIZIPoolExactIn(uint128(amountIn), 0, payer, receiver, currentOffset, 64);
            assembly {
                currentOffset := add(currentOffset, SKIP_LENGTH_UNOSWAP)
            }
        }
        // Balancer V2
        else if (dexId == BALANCER_V2_ID) {
            amountIn = _swapBalancerExactIn(payer, amountIn, receiver, currentOffset);
            assembly {
                currentOffset := add(currentOffset, SKIP_LENGTH_BALANCER_V2)
            }
        }
        // Curve pool types
        else if (dexId < CURVE_V1_MAX_ID) {
            // Curve standard pool
            if (dexId == CURVE_V1_STANDARD_ID) {
                amountIn = _swapCurveGeneral(currentOffset, amountIn, payer, receiver);
                assembly {
                    currentOffset := add(currentOffset, SKIP_LENGTH_CURVE)
                }
            } else {
                assembly {
                    mstore(0, INVALID_DEX)
                    revert(0, 0x4)
                }
            }
        }
        // uniswapV2 style
        else if (dexId < UNISWAP_V2_MAX_ID) {
            amountIn = swapUniV2ExactInComplete(
                amountIn,
                0,
                payer,
                receiver,
                false,
                currentOffset, // we do not slice the path since we deterministically prevent flash swaps
                0
            );
            assembly {
                currentOffset := add(currentOffset, SKIP_LENGTH_UNOSWAP)
            }
        }
        // WOO Fi
        else if (dexId == WOO_FI_ID) {
            address pool;
            assembly {
                pool := shr(96, calldataload(add(currentOffset, 22)))
            }
            // amountIn = swapWooFiExactIn(tokenIn, tokenOut, pool, amountIn, receiver);
            assembly {
                currentOffset := add(currentOffset, SKIP_LENGTH_ADDRESS)
            }
        }
        // Curve NG
        else if (dexId == CURVE_RECEIVED_ID) {
            amountIn = _swapCurveReceived(currentOffset, amountIn, receiver);
            assembly {
                currentOffset := add(currentOffset, SKIP_LENGTH_CURVE)
            }
        }
        // GMX
        else if (dexId == GMX_ID || dexId == KTX_ID) {
            address vault;
            assembly {
                vault := shr(96, calldataload(add(currentOffset, 22)))
            }
            amountIn = swapGMXExactIn(tokenIn, tokenOut, vault, receiver);
            assembly {
                currentOffset := add(currentOffset, SKIP_LENGTH_ADDRESS)
            }
        }
        // DODO V2
        else if (dexId == DODO_ID) {
            address pair;
            uint8 sellQuote;
            assembly {
                let params := calldataload(add(currentOffset, 11))
                pair := shr(8, params)
                sellQuote := and(UINT8_MASK, params)
            }
            amountIn = swapDodoV2ExactIn(sellQuote, pair, receiver);
            assembly {
                currentOffset := add(currentOffset, SKIP_LENGTH_ADDRESS_AND_PARAM)
            }
        }
        // Moe LB
        else if (dexId == LB_ID) {
            address pair;
            assembly {
                pair := shr(96, calldataload(add(currentOffset, 22)))
            }
            amountIn = swapLBexactIn(tokenOut, pair, receiver);
            assembly {
                currentOffset := add(currentOffset, SKIP_LENGTH_ADDRESS)
            }
        } else {
            assembly {
                mstore(0, INVALID_DEX)
                revert(0, 0x4)
            }
        }
        return (amountIn, currentOffset);
    }
}
