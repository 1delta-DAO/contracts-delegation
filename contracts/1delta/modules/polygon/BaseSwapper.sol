// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {TokenTransfer} from "./TokenTransfer.sol";
import {ExoticSwapper} from "./swappers/Exotic.sol";

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
abstract contract BaseSwapper is TokenTransfer, ExoticSwapper {

    /**
     * Fund the first pool for self funded DEXs like Uni V2, GMX, LB, WooFi and Solidly V2 (dexId >= 100) 
     * Extracts and returns the first dexId of the path 
     */
    function _preFundTrade(address payer, uint256 amountIn, bytes calldata path) internal returns (uint256 dexId) {
        assembly {
            dexId := and(shr(80, calldataload(path.offset)), UINT8_MASK)
            ////////////////////////////////////////////////////
            // dexs with ids of 100 and greater are assumed to
            // be based on pre-funding, i.e. the funds have to
            // be sent to the DEX before the swap call  
            ////////////////////////////////////////////////////
            if gt(dexId, 99) {
                let tokenIn := and(
                    ADDRESS_MASK,
                    shr(
                        96,
                        calldataload(path.offset) // nextPoolAddress
                    )
                )
                let nextPool := and(
                    ADDRESS_MASK,
                    shr(
                        96,
                        calldataload(add(path.offset, 22)) // nextPoolAddress
                    )
                )

                ////////////////////////////////////////////////////
                // if the payer is this not contract, we
                // `transferFrom`, otherwise use `transfer`
                ////////////////////////////////////////////////////
                switch eq(payer, address())
                case 0 {
                    let ptr := mload(0x40) // free memory pointer

                    // selector for transferFrom(address,address,uint256)
                    mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
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
                    mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
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
     * @param path path calldata
     * @return amountOut buy amount
     */
    function swapExactIn(
        uint256 amountIn,
        uint256 dexId,
        address payer, // first step
        address receiver, // last step
        bytes calldata path
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
                switch lt(path.length, 67) // maxLength = 66 for single path
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(shr(80, calldataload(add(path.offset, SKIP_LENGTH_UNOSWAP))), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        MAX_SINGLE_LENGTH_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
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
                64, // we do not need end flags
                path
            );
            assembly {
                path.offset := add(path.offset, SKIP_LENGTH_UNOSWAP)
                path.length := sub(path.length, SKIP_LENGTH_UNOSWAP)
            }
        }
        // iZi
        else if (dexId == 49) {
            assembly {
                switch lt(path.length, 67) // same as for Uni V3 CL
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(shr(80, calldataload(add(path.offset, SKIP_LENGTH_UNOSWAP))), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        MAX_SINGLE_LENGTH_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
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
                64,
                path
            );
            assembly {
                path.offset := add(path.offset, SKIP_LENGTH_UNOSWAP)
                path.length := sub(path.length, SKIP_LENGTH_UNOSWAP)
            }
        }
        // Curve pool types
        else if(dexId < 70){
            // Curve standard pool
            if (dexId == 50) {
                assembly {
                    switch lt(path.length, 68) // lengthFull = 20+1+1+20+1+1+1+20 = 65
                    case 1 { currentReceiver := receiver}
                    default {
                        dexId := and(shr(80, calldataload(add(path.offset, 45))), UINT8_MASK)
                        switch gt(dexId, 99) 
                        case 1 {
                            currentReceiver := and(
                                ADDRESS_MASK,
                                shr(
                                    96,
                                    calldataload(
                                        add(
                                            path.offset,
                                            67 // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                        )
                                    ) // poolAddress
                                )
                            )
                        }
                        default {
                            currentReceiver := address()
                        }
                    }
                }
                uint256 pathOffset;
                assembly {
                    pathOffset := path.offset
                }
                amountIn = swapCurveGeneral(pathOffset, amountIn, payer, currentReceiver);
                assembly {
                    path.offset := add(path.offset, 45)
                    path.length := sub(path.length, 45)
                }
            } 
            // curve metapool
            else {
                assembly {
                    switch lt(path.length, 88) // lengthFull = 20+1+1+20+1+1+1+20 = 65
                    case 1 { currentReceiver := receiver}
                    default {
                        dexId := and(shr(80, calldataload(add(path.offset, 65))), UINT8_MASK)
                        switch gt(dexId, 99) 
                        case 1 {
                            currentReceiver := and(
                                ADDRESS_MASK,
                                shr(
                                    96,
                                    calldataload(
                                        add(
                                            path.offset,
                                            87 // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                        )
                                    ) // poolAddress
                                )
                            )
                        }
                        default {
                            currentReceiver := address()
                        }
                    }
                }
                uint256 pathOffset;
                assembly {
                    pathOffset := path.offset
                }
                amountIn = swapCurveMeta(pathOffset, amountIn, payer, currentReceiver);
                assembly {
                    path.offset := add(path.offset, 65)
                    path.length := sub(path.length, 65)
                }
            }
        }
        // uniswapV2 style
        else if (dexId < 150) {
            assembly {
                switch lt(path.length, 67)
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(shr(80, calldataload(add(path.offset, SKIP_LENGTH_UNOSWAP))), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        MAX_SINGLE_LENGTH_UNOSWAP // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
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
                path // we do not slice the path since we deterministically prevent flash swaps
            );
            assembly {
                path.offset := add(path.offset, SKIP_LENGTH_UNOSWAP)
                path.length := sub(path.length, SKIP_LENGTH_UNOSWAP)
            }
        }
        // WOO Fi
        else if (dexId == 150) {
            address tokenIn;
            address tokenOut;
            address pool;
            assembly {
                switch lt(path.length, 65) // same as V2
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(shr(80, calldataload(add(path.offset, 42))), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        64 // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                        )
                    }
                    default {
                        currentReceiver := address()
                    }
                }
                tokenIn := shr(96,  calldataload(path.offset))
                tokenOut := shr(96, calldataload(add(path.offset, 42)))
                pool := shr(96, calldataload(add(path.offset, 22)))
            }
            amountIn = swapWooFiExactIn(
                tokenIn, 
                tokenOut, 
                pool, 
                amountIn,
                currentReceiver
            );
            assembly {
                path.offset := add(path.offset, 42)
                path.length := sub(path.length, 42)
            }
        }
        // GMX
        else if(dexId == 152) {
            address tokenIn;
            address tokenOut;
            address vault;
            assembly {
                switch lt(path.length, 65) // same as V2
                case 1 { currentReceiver := receiver}
                default {
                    dexId := and(shr(80, calldataload(add(path.offset, 42))), UINT8_MASK)
                    switch gt(dexId, 99) 
                    case 1 {
                        currentReceiver := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        64 // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                        )
                    }
                    default {
                        currentReceiver := address()
                    }
                }
                tokenIn := shr(96, calldataload(path.offset))
                tokenOut := shr(96, calldataload(add(path.offset, 42)))
                vault := shr(96, calldataload(add(path.offset, 22)))
            }
            amountIn = swapGMXExactIn(
                tokenIn,
                tokenOut,
                vault,
                currentReceiver
            );
            assembly {
                path.offset := add(path.offset, 42)
                path.length := sub(path.length, 42)
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
        if (path.length > 30) {
            ////////////////////////////////////////////////////
            // In the second or later iterations, the payer is
            // always this contract
            ////////////////////////////////////////////////////
            return swapExactIn(amountIn, dexId, address(this), receiver, path);
        } else return amountIn;
    }

    /**
     * Swaps exact in internally specifically for FOT tokens (uni V2 type only)
     * Will work with nnormal tokens, too, however, it is slightly less efficient
     * Will also never use a flash swap
     * The dexId is assumed to be fetched before in a prefunding action
     * @param amountIn sell amount
     * @param dexId dex identifier
     * @param path path calldata
     * @return amountOut buy amount
     */
    function swapExactInFOT(
        uint256 amountIn,
        uint256 dexId,
        address receiver, // last step
        bytes calldata path
    ) internal returns (uint256 amountOut) {
        address currentReceiver;
        assembly {
            switch lt(path.length, 67)
            case 1 { currentReceiver := receiver}
            default {
                dexId := and(shr(80, calldataload(add(path.offset, SKIP_LENGTH_UNOSWAP))), UINT8_MASK)
                switch gt(dexId, 99) 
                case 1 {
                    currentReceiver := and(
                        ADDRESS_MASK,
                        shr(
                            96,
                            calldataload(
                                add(
                                    path.offset,
                                    MAX_SINGLE_LENGTH_UNOSWAP // 20 + 2 + 20 + 20 + 2 [poolAddress starts here]
                                )
                            ) // poolAddress
                        )
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
            path
        );
        assembly {
            path.offset := add(path.offset, SKIP_LENGTH_UNOSWAP)
            path.length := sub(path.length, SKIP_LENGTH_UNOSWAP)
        }
        ////////////////////////////////////////////////////
        // From there on, we just continue to swap if needed
        // similar to conventional swaps
        ////////////////////////////////////////////////////
        if (path.length > 30) {
            return swapExactIn(amountIn, dexId, address(this), receiver, path);
        } else return amountIn;
    }
}
