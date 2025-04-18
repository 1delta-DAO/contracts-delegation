// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

/**
 * \
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
import {DeltaErrors} from "../shared/errors/Errors.sol";
import {PermitUtils} from "../shared/permit/PermitUtils.sol";
import {DexMappings} from "../shared/swapper/DexMappings.sol";
import {ExoticOffsets} from "../shared/swapper/ExoticOffsets.sol";
import {UnoSwapper} from "../shared/swapper/UnoSwapper.sol";
import {GMXSwapper} from "../shared/swapper/GMXSwapper.sol";
import {LBSwapper} from "../shared/swapper/LBSwapper.sol";
import {DodoV2Swapper} from "../shared/swapper/DodoV2Swapper.sol";

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
    DeltaErrors,
    PermitUtils,
    DexMappings,
    ExoticOffsets,
    UnoSwapper,
    LBSwapper,
    DodoV2Swapper,
    GMXSwapper //
{
    /**
     * Swaps exact in internally using all implemented Dexs
     * Will NOT use a flash swap
     * The dexId is assumed to be fetched before in a prefunding action
     * As such, the parameter can be plugged in here directly
     * @param amountIn sell amount
     * @param dexId dex identifier
     * @return amountOut buy amount
     */
    function swapExactIn(
        uint256 amountIn,
        uint256 dexId,
        address payer, // first step
        address receiver, // last step
        uint256 pathOffset,
        uint256 pathLength
    )
        internal
        returns (uint256 amountOut)
    {
        address currentReceiver;
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
            assembly {
                switch lt(pathLength, MAX_SINGLE_LENGTH_UNOSWAP_HIGH)
                // RECEIVER_OFFSET_UNOSWAP + 1
                case 1 { currentReceiver := receiver }
                default {
                    dexId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNOSWAP - 10
                    switch gt(dexId, 99)
                    case 1 {
                        currentReceiver :=
                            shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default { currentReceiver := address() }
                }
            }
            amountIn = _swapUniswapV3PoolExactIn(
                amountIn,
                0,
                payer,
                currentReceiver,
                pathOffset,
                64 // we do not need end flags
            );
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
            }
        }
        // iZi
        else if (dexId == IZI_ID) {
            assembly {
                switch lt(pathLength, MAX_SINGLE_LENGTH_UNOSWAP_HIGH)
                // RECEIVER_OFFSET_UNOSWAP + 1
                case 1 { currentReceiver := receiver }
                default {
                    dexId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNOSWAP - 10
                    switch gt(dexId, 99)
                    case 1 {
                        currentReceiver :=
                            shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default { currentReceiver := address() }
                }
            }
            amountIn = _swapIZIPoolExactIn(uint128(amountIn), 0, payer, currentReceiver, pathOffset, 64);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
            }
        }
        // Curve pool types
        else if (dexId < CURVE_V1_MAX_ID) {
            // Curve standard pool
            if (dexId == CURVE_V1_STANDARD_ID) {
                assembly {
                    switch lt(pathLength, MAX_SINGLE_LENGTH_CURVE_HIGH)
                    // MAX_SINGLE_LENGTH_CURVE + 1
                    case 1 { currentReceiver := receiver }
                    default {
                        dexId := and(calldataload(add(pathOffset, 35)), UINT8_MASK)
                        switch gt(dexId, 99)
                        case 1 {
                            currentReceiver :=
                                shr(
                                    96,
                                    calldataload(
                                        add(
                                            pathOffset,
                                            RECEIVER_OFFSET_CURVE // 20 + 2 + 20 + 3 + 20 + 2 [poolAddress starts here]
                                        )
                                    ) // poolAddress
                                )
                        }
                        default { currentReceiver := address() }
                    }
                }
                amountIn = _swapCurveGeneral(pathOffset, amountIn, payer, currentReceiver);
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_CURVE)
                    pathLength := sub(pathLength, SKIP_LENGTH_CURVE)
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
            assembly {
                switch lt(pathLength, MAX_SINGLE_LENGTH_UNOSWAP_HIGH)
                case 1 { currentReceiver := receiver }
                default {
                    dexId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNOSWAP - 10
                    switch gt(dexId, 99)
                    case 1 {
                        currentReceiver :=
                            shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default { currentReceiver := address() }
                }
            }
            amountIn = swapUniV2ExactInComplete(
                amountIn,
                0,
                payer,
                currentReceiver,
                false,
                pathOffset, // we do not slice the path since we deterministically prevent flash swaps
                pathLength
            );
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
            }
        }
        // Curve NG
        else if (dexId == CURVE_RECEIVED_ID) {
            assembly {
                switch lt(pathLength, MAX_SINGLE_LENGTH_CURVE_HIGH)
                //
                case 1 { currentReceiver := receiver }
                default {
                    dexId := and(calldataload(add(pathOffset, 35)), UINT8_MASK)
                    switch gt(dexId, 99)
                    case 1 {
                        currentReceiver :=
                            shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_CURVE // 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default { currentReceiver := address() }
                }
            }
            amountIn = _swapCurveReceived(pathOffset, amountIn, currentReceiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_CURVE)
                pathLength := sub(pathLength, SKIP_LENGTH_CURVE)
            }
        }
        // GMX
        else if (dexId == GMX_ID || dexId == KTX_ID) {
            address tokenIn;
            address tokenOut;
            address vault;
            assembly {
                switch lt(pathLength, MAX_SINGLE_LENGTH_ADDRESS_HIGH)
                // same as V2
                case 1 { currentReceiver := receiver }
                default {
                    dexId := and(calldataload(add(pathOffset, 32)), UINT8_MASK)
                    switch gt(dexId, 99)
                    case 1 {
                        currentReceiver :=
                            shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_SINGLE_LENGTH_ADDRESS // 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default { currentReceiver := address() }
                }
                tokenIn := shr(96, calldataload(pathOffset))
                tokenOut := shr(96, calldataload(add(pathOffset, 42)))
                vault := shr(96, calldataload(add(pathOffset, 22)))
            }
            amountIn = swapGMXExactIn(tokenIn, tokenOut, vault, currentReceiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_ADDRESS)
                pathLength := sub(pathLength, SKIP_LENGTH_ADDRESS)
            }
        }
        // DODO V2
        else if (dexId == DODO_ID) {
            address pair;
            uint8 sellQuote;
            assembly {
                switch lt(pathLength, MAX_SINGLE_LENGTH_ADDRESS_AND_PARAM_HIGH)
                //
                case 1 { currentReceiver := receiver }
                default {
                    dexId := and(calldataload(add(pathOffset, 33)), UINT8_MASK)
                    switch gt(dexId, 99)
                    case 1 {
                        currentReceiver :=
                            shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_SINGLE_LENGTH_ADDRESS_AND_PARAM // 20 + 2 + 20 + 1 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default { currentReceiver := address() }
                }
                let params := calldataload(add(pathOffset, 11))
                pair := shr(8, params)
                sellQuote := and(UINT8_MASK, params)
            }
            amountIn = swapDodoV2ExactIn(sellQuote, pair, currentReceiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_ADDRESS_AND_PARAM)
                pathLength := sub(pathLength, SKIP_LENGTH_ADDRESS_AND_PARAM)
            }
        }
        // Moe LB
        else if (dexId == LB_ID) {
            address tokenIn;
            address tokenOut;
            address pair;
            assembly {
                switch lt(pathLength, MAX_SINGLE_LENGTH_ADDRESS_HIGH)
                // same as V2
                case 1 { currentReceiver := receiver }
                default {
                    dexId := and(calldataload(add(pathOffset, 32)), UINT8_MASK)
                    switch gt(dexId, 99)
                    case 1 {
                        currentReceiver :=
                            shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_SINGLE_LENGTH_ADDRESS // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default { currentReceiver := address() }
                }
                tokenIn := shr(96, calldataload(pathOffset))
                tokenOut := shr(96, calldataload(add(pathOffset, 42)))
                pair := shr(96, calldataload(add(pathOffset, 22)))
            }
            amountIn = swapLBexactIn(tokenOut, pair, currentReceiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_ADDRESS)
                pathLength := sub(pathLength, SKIP_LENGTH_ADDRESS)
            }
        } else {
            assembly {
                mstore(0, INVALID_DEX)
                revert(0, 0x4)
            }
        }

        ////////////////////////////////////////////////////
        // We recursively re-call this function until the
        // path is short enough as a break criteria
        ////////////////////////////////////////////////////
        if (pathLength > 30) {
            ////////////////////////////////////////////////////
            // In the second or later iterations, the payer is
            // always this contract
            ////////////////////////////////////////////////////
            return swapExactIn(amountIn, dexId, address(this), receiver, pathOffset, pathLength);
        } else {
            return amountIn;
        }
    }

    /**
     * Swaps exact in internally specifically for FOT tokens (uni V2 type only)
     * Will work with nnormal tokens, too, however, it is slightly less efficient
     * Will also never use a flash swap
     * The dexId is assumed to be fetched before in a prefunding action
     * @param amountIn sell amount
     * @param dexId dex identifier
     * @return amountOut buy amount
     */
    function swapExactInFOT(
        uint256 amountIn,
        uint256 dexId,
        address receiver, // last step
        uint256 pathOffset,
        uint256 pathLength
    )
        internal
        returns (uint256 amountOut)
    {
        address currentReceiver;
        assembly {
            switch lt(pathLength, MAX_SINGLE_LENGTH_UNOSWAP_HIGH)
            case 1 { currentReceiver := receiver }
            default {
                dexId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNOSWAP - 10
                switch gt(dexId, 99)
                case 1 {
                    currentReceiver :=
                        shr(
                            96,
                            calldataload(
                                add(
                                    pathOffset,
                                    RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                )
                            ) // poolAddress
                        )
                }
                default { currentReceiver := address() }
            }
        }
        amountIn = swapUniV2ExactInFOT(amountIn, currentReceiver, pathOffset);
        assembly {
            pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
            pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
        }
        ////////////////////////////////////////////////////
        // From there on, we just continue to swap if needed
        // similar to conventional swaps
        ////////////////////////////////////////////////////
        if (pathLength > 30) {
            return swapExactIn(amountIn, dexId, address(this), receiver, pathOffset, pathLength);
        } else {
            return amountIn;
        }
    }
}
