// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {DexMappings} from "../modules/shared/swapper/DexMappings.sol";
import {QuoterParamsLayout} from "./dex/ParamsLayout.sol";
import {DodoV2Quoter} from "./dex/DodoV2.sol";
import {CurveQuoter} from "./dex/Curve.sol";
import {LBQuoter} from "./dex/LB.sol";
import {V2TypeQuoter} from "./dex/V2Type.sol";
import {V3TypeQuoter} from "./dex/V3Type.sol";
import {SyncQuoter} from "./dex/Sync.sol";
import {WooFiQuoter} from "./dex/WooFi.sol";
import {SyncQuoter} from "./dex/Sync.sol";

/**
 * Quoter contract
 * Paths have to be encoded as follows: token0 (address) | param0 (uint24) | poolId (uint8) | token1 (address) |
 */
contract OneDeltaQuoter is
    DodoV2Quoter,
    CurveQuoter,
    LBQuoter,
    V2TypeQuoter,
    V3TypeQuoter,
    SyncQuoter,
    WooFiQuoter,
    QuoterParamsLayout,
    DexMappings //
{
    error invalidDexId();

    // masking

    uint256 internal constant UINT16_MASK = 0xffff;
    uint256 internal constant UINT8_MASK = 0xff;

    /// @dev Get the quote for an exactIn swap between an array of Stable, V2 and/or V3 pools
    function quoteExactInput(
        bytes calldata path, // calldata more efficient than memory
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        while (true) {
            address tokenIn;
            address tokenOut;
            address pair;
            uint8 poolId;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord) // get first token
                poolId := shr(88, firstWord) //
                pair := calldataload(add(path.offset, 9)) // pool starts at 21st byte
            }

            // v3 types
            if (poolId < UNISWAP_V3_MAX_ID) {
                assembly {
                    // tokenOut starts at 43th byte for CL
                    tokenOut := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                }
                amountIn = getV3TypeAmountOut(tokenIn, tokenOut, pair, amountIn);
                path = path[CL_PARAM_LENGTH:];
            }
            // iZi
            else if (poolId == IZI_ID) {
                assembly {
                    // tokenOut starts at 43th byte for CL
                    tokenOut := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                }
                amountIn = getIziAmountOut(tokenIn, tokenOut, pair, uint128(amountIn));
                path = path[CL_PARAM_LENGTH:];
            } else if (poolId == CURVE_V1_STANDARD_ID) {
                uint8 indexIn;
                uint8 indexOut;
                uint8 selectorId;
                assembly {
                    let indexData := calldataload(add(path.offset, 21))
                    indexIn := and(shr(88, indexData), 0xff)
                    indexOut := and(shr(80, indexData), 0xff)
                    selectorId := and(shr(72, indexData), 0xff)
                }
                amountIn = getCurveAmountOut(indexIn, indexOut, selectorId, pair, amountIn);
                path = path[CURVE_PARAM_LENGTH:];
            } else if (poolId == CURVE_FORK_ID) {
                uint8 indexIn;
                uint8 indexOut;
                assembly {
                    let indexData := calldataload(add(path.offset, 21))
                    indexIn := and(shr(88, indexData), 0xff)
                    indexOut := and(shr(80, indexData), 0xff)
                }
                amountIn = getCurveAmountOut(indexIn, indexOut, 2, pair, amountIn);
                path = path[CURVE_PARAM_LENGTH:];
            }
            // v2 types
            else if (poolId < UNISWAP_V2_MAX_ID) {
                uint256 feeDenom;
                assembly {
                    // tokenOut starts at 43rd byte
                    tokenOut := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                    feeDenom := and(UINT16_MASK, shr(80, calldataload(add(path.offset, 21))))
                }
                amountIn = getV2TypeAmountOut(pair, tokenIn, tokenOut, amountIn, feeDenom, poolId);
                path = path[V2_PARAM_LENGTH:];
            } else if (poolId == WOO_FI_ID) {
                assembly {
                    // tokenOut starts at 41st byte
                    tokenOut := shr(96, calldataload(add(path.offset, 41)))
                }
                amountIn = getWooFiAmountOut(tokenIn, tokenOut, amountIn);
                path = path[EXOTIC_PARAM_LENGTH:];
            } else if (poolId == LB_ID) {
                assembly {
                    // tokenOut starts at 41st byte
                    tokenOut := shr(96, calldataload(add(path.offset, 41)))
                }
                amountIn = getLBAmountOut(tokenOut, amountIn, pair);
                path = path[EXOTIC_PARAM_LENGTH:];
            } else if (poolId == SYNC_SWAP_ID) {
                amountIn = quoteSyncSwapExactIn(pair, tokenIn, amountIn);
                path = path[EXOTIC_PARAM_LENGTH:];
            } else if (poolId == DODO_ID) {
                uint256 sellQuote;
                assembly {
                    // sellQuote starts after the pair
                    sellQuote := and(UINT8_MASK, calldataload(add(path.offset, 10)))
                }
                amountIn = getDodoV2AmountOut(pair, sellQuote, amountIn);
                path = path[DODO_PARAM_LENGTH:];
            } else if (poolId == CURVE_RECEIVED_ID) {
                uint8 indexIn;
                uint8 indexOut;
                uint8 selectorId;
                assembly {
                    let indexData := calldataload(add(path.offset, 21))
                    indexIn := and(shr(88, indexData), 0xff)
                    indexOut := and(shr(80, indexData), 0xff)
                    selectorId := and(shr(72, indexData), 0xff)
                }
                amountIn = getCurveAmountOut(indexIn, indexOut, selectorId, pair, amountIn);
                path = path[CURVE_PARAM_LENGTH:];
            } else {
                revert invalidDexId();
            }

            /// decide whether to continue or terminate
            if (path.length < 40) {
                return amountIn;
            }
        }
    }

    /// @dev Get the quote for an exactIn swap between an array of Stable, V2 and/or V3 pools
    function quoteExactOutput(
        bytes calldata path, // calldata more efficient than memory
        uint256 amountOut
    ) public returns (uint256 amountIn) {
        while (true) {
            address tokenIn;
            address tokenOut;
            uint8 poolId;
            address pair;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenOut := shr(96, firstWord) // get first token
                poolId := shr(88, firstWord) //
                pair := shr(96, calldataload(add(path.offset, 21))) //
            }

            // v3 types
            if (poolId < UNISWAP_V3_MAX_ID) {
                assembly {
                    // tokenIn starts at 43th byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                }
                amountOut = getV3TypeAmountIn(tokenIn, tokenOut, pair, amountOut);
                path = path[CL_PARAM_LENGTH:];
            } else if (poolId == IZI_ID) {
                assembly {
                    // tokenIn starts at 43th byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                }
                amountOut = getIziAmountIn(tokenIn, tokenOut, pair, uint128(amountOut));
                path = path[CL_PARAM_LENGTH:];
            }
            // v2 types
            else if (poolId < UNISWAP_V2_MAX_ID) {
                uint256 feeDenom;
                assembly {
                    // tokenIn starts at 43th byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                    feeDenom := and(UINT16_MASK, shr(80, calldataload(add(path.offset, 21))))
                }
                amountOut = getV2TypeAmountIn(pair, tokenIn, tokenOut, amountOut, feeDenom, poolId);
                path = path[V2_PARAM_LENGTH:];
            } else if (poolId == LB_ID) {
                assembly {
                    // tokenIn starts at 41st byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, 41)))
                }
                amountOut = getLBAmountIn(tokenOut, amountOut, pair);
                path = path[EXOTIC_PARAM_LENGTH:];
            } else {
                revert invalidDexId();
            }
            /// decide whether to continue or terminate
            if (path.length < 40) {
                return amountOut;
            }
        }
    }
}
