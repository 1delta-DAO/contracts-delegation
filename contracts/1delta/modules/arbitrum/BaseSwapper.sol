// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {BaseLending} from "./BaseLending.sol";
import {PermitUtils} from "../shared/permit/PermitUtils.sol";

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
abstract contract BaseSwapper is BaseLending, PermitUtils {

    // offset for receiver address for most DEX types (uniswap, curve etc.)
    uint256 internal constant RECEIVER_OFFSET_UNOSWAP = 66;

    /**
     * Fund the first pool for self funded DEXs like Uni V2, GMX, LB, WooFi and Solidly V2 (dexId >= 100) 
     * Extracts and returns the first dexId of the path 
     */
    function _preFundTrade(address payer, uint256 amountIn, uint256 pathOffset) internal returns (uint256 dexId) {
        assembly {
            dexId := and(shr(80, calldataload(pathOffset)), UINT8_MASK)
            ////////////////////////////////////////////////////
            // dexs with ids of 100 and greater are assumed to
            // be based on pre-funding, i.e. the funds have to
            // be sent to the DEX before the swap call  
            ////////////////////////////////////////////////////
            if gt(dexId, 99) {
                let tokenIn := shr(
                    96,
                    calldataload(pathOffset) // nextPoolAddress
                )
                let nextPool := shr(
                    96,
                    calldataload(add(pathOffset, 22)) // nextPoolAddress
                )

                ////////////////////////////////////////////////////
                // if the payer is this not contract, we
                // `transferFrom`, otherwise use `transfer`
                ////////////////////////////////////////////////////
                switch eq(payer, address())
                case 0 {
                    let ptr := mload(0x40) // free memory pointer

                    // selector for transferFrom(address,address,uint256)
                    mstore(ptr, ERC20_TRANSFER_FROM)
                    mstore(add(ptr, 0x04), payer)
                    mstore(add(ptr, 0x24), nextPool)
                    mstore(add(ptr, 0x44), amountIn)

                    let success := call(gas(), tokenIn, 0, ptr, 0x64, ptr, 32)

                    let rdsize := returndatasize()

                    // Check for ERC20 success. ERC20 tokens should return a boolean,
                    // but some don't. We accept 0-length return data as success, or at
                    // least 32 bytes that starts with a 32-byte boolean true.
                    success := and(
                        success, // call itself succeeded
                        or(
                            iszero(rdsize), // no return data, or
                            and(
                                iszero(lt(rdsize, 32)), // at least 32 bytes
                                eq(mload(ptr), 1) // starts with uint256(1)
                            )
                        )
                    )

                    if iszero(success) {
                        returndatacopy(0, 0, rdsize)
                        revert(0, rdsize)
                    }
                }
                default {
                    let ptr := mload(0x40) // free memory pointer

                    // selector for transfer(address,uint256)
                    mstore(ptr, ERC20_TRANSFER)
                    mstore(add(ptr, 0x04), nextPool)
                    mstore(add(ptr, 0x24), amountIn)

                    let success := call(gas(), tokenIn, 0, ptr, 0x44, ptr, 32)

                    let rdsize := returndatasize()

                    // Check for ERC20 success. ERC20 tokens should return a boolean,
                    // but some don't. We accept 0-length return data as success, or at
                    // least 32 bytes that starts with a 32-byte boolean true.
                    success := and(
                        success, // call itself succeeded
                        or(
                            iszero(rdsize), // no return data, or
                            and(
                                iszero(lt(rdsize, 32)), // at least 32 bytes
                                eq(mload(ptr), 1) // starts with uint256(1)
                            )
                        )
                    )

                    if iszero(success) {
                        returndatacopy(0, 0, rdsize)
                        revert(0, rdsize)
                    }
                }
            }
        }
    }

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
    ) internal returns (uint256 amountOut) {
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
        if (dexId < 49) {
            assembly {
                switch lt(pathLength, 67) // RECEIVER_OFFSET_UNOSWAP + 1
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNOSWAP - 10
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default {
                        currentReceiver := address()
                    }
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
        else if (dexId == 49) {
            assembly {
                switch lt(pathLength, 67) // RECEIVER_OFFSET_UNOSWAP + 1
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNOSWAP - 10
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default {
                        currentReceiver := address()
                    }
                }
            }
            amountIn = _swapIZIPoolExactIn(
                uint128(amountIn),
                0,
                payer,
                currentReceiver,
                pathOffset,
                64
            );
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
            }
        }
        // Balancer V2
        else if (dexId == 50) {
            assembly {
                switch lt(pathLength, 78) // MAX_SINGLE_LENGTH_BALANCER_V2 + 1
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(calldataload(add(pathOffset, 45)), UINT8_MASK) // SKIP_LENGTH_BALANCER_V2 - 10
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        MAX_SINGLE_LENGTH_BALANCER_V2 // 
                                    )
                                ) // poolAddress
                            )
                    }
                    default {
                        currentReceiver := address()
                    }
                }
            }
            amountIn = _swapBalancerExactIn(
                payer,
                amountIn,
                currentReceiver,
                pathOffset
            );
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_BALANCER_V2)
                pathLength := sub(pathLength, SKIP_LENGTH_BALANCER_V2)
            }
        }
        // Curve pool types
        else if(dexId < 70){
            // Curve standard pool
            if (dexId == 60) {
                assembly {
                    switch lt(pathLength, 69) // MAX_SINGLE_LENGTH_CURVE + 1
                    case 1 { currentReceiver := receiver}
                    default {
                        dexId := and(calldataload(add(pathOffset, 35)), UINT8_MASK)
                        switch gt(dexId, 99) 
                        case 1 {
                            currentReceiver := shr(
                                    96,
                                    calldataload(
                                        add(
                                            pathOffset,
                                            MAX_SINGLE_LENGTH_CURVE // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                        )
                                    ) // poolAddress
                                )
                        }
                        default {
                            currentReceiver := address()
                        }
                    }
                }
                amountIn = _swapCurveGeneral(pathOffset, amountIn, payer, currentReceiver);
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_CURVE)
                    pathLength := sub(pathLength, SKIP_LENGTH_CURVE)
                }
            }
            else {
                assembly {
                    mstore(0, INVALID_DEX)
                    revert (0, 0x4)
                }
            }
        }
        // uniswapV2 style
        else if (dexId < 150) {
            assembly {
                switch lt(pathLength, 67)
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNOSWAP - 10
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default {
                        currentReceiver := address()
                    }
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
        // WOO Fi
        else if (dexId == 150) {
            address tokenIn;
            address tokenOut;
            address pool;
            assembly {
                switch lt(pathLength, 65) // same as V2
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(calldataload(add(pathOffset, 32)), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        64 // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default {
                        currentReceiver := address()
                    }
                }
                tokenIn := shr(96,  calldataload(pathOffset))
                tokenOut := shr(96, calldataload(add(pathOffset, 42)))
                pool := shr(96, calldataload(add(pathOffset, 22)))
            }
            amountIn = swapWooFiExactIn(
                tokenIn, 
                tokenOut, 
                pool, 
                amountIn,
                currentReceiver
            );
            assembly {
                pathOffset := add(pathOffset, 42)
                pathLength := sub(pathLength, 42)
            }
        }
        // Curve NG
        else if (dexId == 151) {
            assembly {
                switch lt(pathLength, 68) // 
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(calldataload(add(pathOffset, 35)), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        MAX_SINGLE_LENGTH_CURVE_NG // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default {
                        currentReceiver := address()
                    }
                }
            }
            amountIn = _swapCurveNG(pathOffset, amountIn, currentReceiver);
            assembly {
                pathOffset := add(pathOffset, SKIP_LENGTH_CURVE_NG)
                pathLength := sub(pathLength, SKIP_LENGTH_CURVE_NG)
            }
        }
        // GMX
        else if(dexId == 152) {
            address tokenIn;
            address tokenOut;
            address vault;
            assembly {
                switch lt(pathLength, 65) // same as V2
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(calldataload(add(pathOffset, 32)), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        64 // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default {
                        currentReceiver := address()
                    }
                }
                tokenIn := shr(96, calldataload(pathOffset))
                tokenOut := shr(96, calldataload(add(pathOffset, 42)))
                vault := shr(96, calldataload(add(pathOffset, 22)))
            }
            amountIn = swapGMXExactIn(
                tokenIn,
                tokenOut,
                vault,
                currentReceiver
            );
            assembly {
                pathOffset := add(pathOffset, 42)
                pathLength := sub(pathLength, 42)
            }
        }
        // DODO V2
        else if(dexId == 153) {
            address pair;
            uint8 sellQuote;
            assembly {
                switch lt(pathLength, 66) // same as V2
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(calldataload(add(pathOffset, 33)), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        65 // 20 + 2 + 20 + 1 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default {
                        currentReceiver := address()
                    }
                }
                let params := calldataload(add(pathOffset, 11))
                pair := shr(8, params)
                sellQuote := and(UINT8_MASK, params)
            }
            amountIn = swapDodoV2ExactIn(
                sellQuote,
                pair,
                currentReceiver
            );
            assembly {
                pathOffset := add(pathOffset, 43)
                pathLength := sub(pathLength, 43)
            }
        }
        // Moe LB
        else if (dexId == 154) {
            address tokenIn;
            address tokenOut;
            address pair;
            assembly {
                switch lt(pathLength, 65) // same as V2
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(calldataload(add(pathOffset, 32)), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        64 // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                    }
                    default {
                        currentReceiver := address()
                    }
                }
                tokenIn := shr(96, calldataload(pathOffset))
                tokenOut := shr(96, calldataload(add(pathOffset, 42)))
                pair := shr(96, calldataload(add(pathOffset, 22)))
            }
            amountIn = swapLBexactIn(
                tokenOut,
                pair,
                currentReceiver
            );
            assembly {
                pathOffset := add(pathOffset, 42)
                pathLength := sub(pathLength, 42)
            }
        }
        else {
            assembly {
                mstore(0, INVALID_DEX)
                revert (0, 0x4)
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
        } else return amountIn;
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
    ) internal returns (uint256 amountOut) {
        address currentReceiver;
        assembly {
            switch lt(pathLength, 67)
            case 1 { currentReceiver := receiver}
            default {dexId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNOSWAP - 10
                switch gt(dexId, 99) 
                case 1 {
                    currentReceiver := shr(
                            96,
                            calldataload(
                                add(
                                    pathOffset,
                                    RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                )
                            ) // poolAddress
                        )
                }
                default {
                    currentReceiver := address()
                }
            }
        }
        amountIn = swapUniV2ExactInFOT(
            amountIn,
            currentReceiver,
            pathOffset
        );
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
        } else return amountIn;
    }
}
