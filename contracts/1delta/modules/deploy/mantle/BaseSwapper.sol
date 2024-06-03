// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {TokenTransfer} from "../../../libraries/TokenTransfer.sol";
import {UniTypeSwapper} from "./swappers/UniType.sol";
import {CurveSwapper} from "./swappers/Curve.sol";
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
abstract contract BaseSwapper is TokenTransfer, UniTypeSwapper, CurveSwapper, ExoticSwapper {
    error invalidDexId();
    error Slippage();

    constructor() {}

    /**
     * Get the last token from path calldata for the margin case
     * As such, we assume that 2 flags (lender & payConfig) preceed
     * The data.
     * @param data input data
     * @return token address
     */
    function getLastToken(bytes calldata data) internal pure returns (address token) {
        assembly {
            token := shr(96, calldataload(add(data.offset, sub(data.length, 22))))
        }
    }


    function _preFundTrade(
        address payer,
        uint256 amountIn,
        bytes calldata path
    ) internal returns (address receiver) {
        address tokenIn;
        uint256 dexId;
        address nextPool;
        assembly {
            tokenIn := and(
                    ADDRESS_MASK,
                    shr(
                        96,
                        calldataload(path.offset) // nextPoolAddress
                    )
            )
            nextPool := and(
                    ADDRESS_MASK,
                    shr(
                        96,
                        calldataload(add(path.offset, 22)) // nextPoolAddress
                    )
            )
            
            dexId := and(shr(80, calldataload(path.offset)), UINT8_MASK)
            switch gt(dexId, 99) 
            case 1 {
                // transfer to nextPool
                receiver := nextPool
            }
            default {
                receiver := address()
            }
        }
        if( dexId > 99) {
           if(payer == address(this)) _transferERC20Tokens(tokenIn, receiver, amountIn);
           else _transferERC20TokensFrom(tokenIn, payer, receiver, amountIn);
        } 
    }


    function _preFundTradeMargin(
        address payer,
        uint256 amountIn,
        bytes calldata path
    ) internal returns (address receiver) {
        address tokenIn;
        uint256 dexId;
        address nextPool;
        assembly {
            tokenIn := and(
                    ADDRESS_MASK,
                    shr(
                        96,
                        calldataload(path.offset) // nextPoolAddress
                    )
            )
            nextPool := and(
                    ADDRESS_MASK,
                    shr(
                        96,
                        calldataload(add(path.offset, 22)) // nextPoolAddress
                    )
            )
            
            dexId := and(shr(80, calldataload(path.offset)), UINT8_MASK)
            switch gt(dexId, 99) 
            case 1 {
                // transfer to nextPool
                receiver := nextPool
            }
            default {
                receiver := address()
            }
        }
        if( dexId > 99) {
           if(payer == address(this)) _transferERC20Tokens(tokenIn, receiver, amountIn);
           else _transferERC20TokensFrom(tokenIn, payer, receiver, amountIn);
        } 
    }


    function _getPoolReceiver(uint256 offset, bytes calldata path) internal view returns (address receiver) {
        uint256 dexId;
        assembly {
            dexId := and(shr(80, calldataload(path.offset)), UINT8_MASK)
            switch gt(dexId, 99) 
            case 1 {
                // transfer to nextPool
                receiver := and(
                    ADDRESS_MASK,
                    shr(
                        96,
                        calldataload(add(path.offset, offset)) // nextPoolAddress
                    )
            )
            }
            default {
                receiver := address()
            }
        }
    }

    /**
     * Swaps exact in internally using all implemented Dexs
     * Will NOT use a flash swap
     * @param amountIn sell amount
     * @param path path calldata
     * @return amountOut buy amount
     */
    function swapExactIn(
        uint256 amountIn,
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
        // flash-swaps 
        ////////////////////////////////////////////////////
        uint256 dexId;
        assembly {
            dexId := and(shr(80, calldataload(path.offset)), UINT8_MASK)
            currentReceiver := address()
        }
        // uniswapV3 style
        if (dexId < 49) {
            assembly {
                switch lt(path.length, 66)
                case 1 { currentReceiver := receiver}
                default {
                    let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    switch gt(nextId, 99) 
                    case 1 {
                        currentReceiver := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        66 // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
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
                path[:64] // we do not need end flags
            );
            assembly {
                path.offset := add(path.offset, 44)
                path.length := sub(path.length, 44)
            }
        }
        // iZi
        else if (dexId == 49) {
            assembly {
                switch lt(path.length, 66)
                case 1 { currentReceiver := receiver}
                default {
                    let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    switch gt(nextId, 99) 
                    case 1 {
                        currentReceiver := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        66 // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
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
                path[:64]
            );
            assembly {
                path.offset := add(path.offset, 44)
                path.length := sub(path.length, 44)
            }
        }
        // Stratum 3USD with wrapper
        else if (dexId == 50) {
            assembly {
                if lt(path.length, 44) { currentReceiver := receiver}
            }
            address tokenIn;
            address tokenOut;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord)
                tokenOut := shr(96, calldataload(add(path.offset, 25)))
            }
            amountIn = swapStratum3(tokenIn, tokenOut, amountIn, payer, currentReceiver);
            assembly {
                path.offset := add(path.offset, 23)
                path.length := sub(path.length, 23)
            }
        }
        // Curve stable general
        else if (dexId == 51) {
            assembly {
                switch lt(path.length, 74)
                case 1 { currentReceiver := receiver}
                default {
                    let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    switch gt(nextId, 99) 
                    case 1 {
                        currentReceiver := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        66 // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
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
            amountIn = swapCurveGeneral(path[:64], amountIn, payer, currentReceiver);
            assembly {
                path.offset := add(path.offset, 44)
                path.length := sub(path.length, 44)
            }
        }
        // uniswapV2 style
        else if (dexId < 150) {
            assembly {
                switch lt(path.length, 64)
                case 1 { currentReceiver := receiver}
                default {
                    let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    switch gt(nextId, 99) 
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
            }
            amountIn = swapUniV2ExactInComplete(
                amountIn,
                0,
                payer,
                currentReceiver,
                false,
                path[:62]
            );
            assembly {
                path.offset := add(path.offset, 42)
                path.length := sub(path.length, 42)
            }
        }
        // WOO Fi
        else if (dexId == 150) {
            assembly {
                switch lt(path.length, 64)
                case 1 { currentReceiver := receiver}
                default {
                    let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    switch gt(nextId, 99) 
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
            }
            address tokenIn;
            address tokenOut;
            address pool;
            assembly {
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
        // Moe LB
        else if (dexId == 151) {
            assembly {
                switch lt(path.length, 64)
                case 1 { currentReceiver := receiver}
                default {
                    let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    switch gt(nextId, 99) 
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
            }
            address tokenIn;
            address tokenOut;
            address pair;
            assembly {
                tokenIn := shr(96, calldataload(path.offset))
                tokenOut := shr(96, calldataload(add(path.offset, 42)))
                pair := shr(96, calldataload(add(path.offset, 22)))
            }
            amountIn = swapLBexactIn(
                tokenOut,
                pair,
                currentReceiver
            );
            assembly {
                path.offset := add(path.offset, 42)
                path.length := sub(path.length, 42)
            }
        } 
        // GMX
        else if(dexId == 152) {
            assembly {
                switch lt(path.length, 64)
                case 1 { currentReceiver := receiver}
                default {
                    let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    switch gt(nextId, 99) 
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
            }
            address tokenIn;
            address tokenOut;
            address vault;
            assembly {
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
         else
            revert invalidDexId();
        
        ////////////////////////////////////////////////////
        // We recursively re-call this function until the
        // path is short enough as a break criteria
        ////////////////////////////////////////////////////
        if (path.length > 30) {
            ////////////////////////////////////////////////////
            // In the second or later iterations, the payer is
            // always this contract
            ////////////////////////////////////////////////////
            return swapExactIn(amountIn, address(this), receiver, path);
        } else return amountIn;
    }


    /**
     * Swaps exact in through a single Dex
     * Will NOT use a flash swap
     * @param amountIn sell amount
     * @param path path calldata
     * @return amountOut buy amount
     */
    function swapExactInSingle(
        uint256 amountIn,
        uint256 minOut,
        address receiver, // last step
        bytes calldata path
    ) external returns (uint256 amountOut) {
        ////////////////////////////////////////////////////
        // No loop, direct single swaps are more efficient
        // since we can skip larger chunks of the logic
        ////////////////////////////////////////////////////
        uint256 dexId;
        assembly {
            dexId := and(shr(80, calldataload(path.offset)), UINT8_MASK)
        }
        // uniswapV3 style
        if (dexId < 49) {
            amountOut = _swapUniswapV3PoolExactIn(
                amountIn,
                0,
                msg.sender,
                receiver,
                path[:64] // we do not need end flags
            );
        }
        // iZi
        else if (dexId == 49) {
            amountOut = _swapIZIPoolExactIn(
                uint128(amountIn),
                0,
                msg.sender,
                receiver,
                path[:64]
            );
        }
        // Stratum 3USD with wrapper
        else if (dexId == 50) {
            address tokenIn;
            address tokenOut;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord)
                tokenOut := shr(96, calldataload(add(path.offset, 25)))
            }
            amountOut = swapStratum3(tokenIn, tokenOut, amountIn, msg.sender, receiver);
        }
        // Curve stable general
        else if (dexId == 51) {
            amountOut = swapCurveGeneral(path[:64], amountIn, msg.sender, receiver);
        }
        // uniswapV2 style
        else if (dexId < 150) {
            amountOut = swapUniV2ExactInComplete(
                amountIn,
                0,
                msg.sender,
                receiver,
                false,
                path[:62]
            );
        }
        // WOO Fi
        else if (dexId == 150) {
            address tokenIn;
            address tokenOut;
            address pool;
            assembly {
                tokenIn := shr(96,  calldataload(path.offset))
                tokenOut := shr(96, calldataload(add(path.offset, 42)))
                pool := shr(96, calldataload(add(path.offset, 22)))
            }
            amountOut = swapWooFiExactIn(
                tokenIn,
                tokenOut,
                pool,
                amountIn,
                receiver
            );
        }
        // Moe LB
        else if (dexId == 151) {
            address tokenIn;
            address tokenOut;
            address pair;
            assembly {
                tokenIn := shr(96, calldataload(path.offset))
                tokenOut := shr(96, calldataload(add(path.offset, 42)))
                pair := shr(96, calldataload(add(path.offset, 22)))
            }
            amountOut = swapLBexactIn(
                tokenOut,
                pair,
                receiver
            );
        } 
        // KTX / GMX
        else if(dexId == 152) {
            address tokenIn;
            address tokenOut;
            address vault;
            assembly {
                tokenIn := shr(96, calldataload(path.offset))
                tokenOut := shr(96, calldataload(add(path.offset, 42)))
                vault := shr(96, calldataload(add(path.offset, 22)))
            }
            amountOut = swapGMXExactIn(tokenIn, tokenOut, vault, receiver);
        } 
         else
            revert invalidDexId();

        if(minOut > amountOut) revert Slippage();
    }
}
