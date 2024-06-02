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
        uint256 identifier;
        assembly {
            identifier := and(shr(80, calldataload(path.offset)), UINT8_MASK)
            currentReceiver := address()
        }
        // uniswapV3 style
        if (identifier < 49) {
            assembly {
                switch lt(path.length, 66)
                case 1 { currentReceiver := receiver}
                default {
                    // let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    // switch gt(nextId, 49) 
                    // case 1 {
                    //     currentReceiver := and(ADDRESS_MASK, shr(96, calldataload(add(path.offset, 42))))
                    // }
                    // default {
                    //     currentReceiver := address()
                    // }
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
        else if (identifier == 49) {
            assembly {
                if lt(path.length, 66) { currentReceiver := receiver}
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
        else if (identifier == 50) {
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
        else if (identifier == 51) {
            assembly {
                if lt(path.length, 74) { currentReceiver := receiver}
            }
            amountIn = swapCurveGeneral(path[:64], amountIn, payer, currentReceiver);
            assembly {
                path.offset := add(path.offset, 44)
                path.length := sub(path.length, 44)
            }
        }
        // uniswapV2 style
        else if (identifier < 150) {
            assembly {
                if lt(path.length, 64) { currentReceiver := receiver}
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
        else if (identifier == 150) {
            assembly {
                if lt(path.length, 44) { currentReceiver := receiver}
            }
            address tokenIn;
            address tokenOut;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord)
                tokenOut := shr(96, calldataload(add(path.offset, 22)))
            }
            amountIn = swapWooFiExactIn(tokenIn, tokenOut, amountIn, payer, currentReceiver);
            assembly {
                path.offset := add(path.offset, 21)
                path.length := sub(path.length, 21)
            }
        }
        // Moe LB
        else if (identifier == 151) {
            assembly {
                if lt(path.length, 46) { currentReceiver := receiver}
            }
            address tokenIn;
            address tokenOut;
            uint16 bin;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord)
                tokenOut := shr(96, calldataload(add(path.offset, 24)))
                bin := and(shr(64, firstWord), UINT16_MASK)
            }
            amountIn = swapLBexactIn(
                tokenIn,
                tokenOut,
                amountIn,
                payer,
                currentReceiver,
                bin
            );
            assembly {
                path.offset := add(path.offset, 24)
                path.length := sub(path.length, 24)
            }
        } 
        // KTX / GMX
        else if(identifier == 152) {
            assembly {
                if lt(path.length, 44) { currentReceiver := receiver}
            }
            address tokenIn;
            address tokenOut;
            assembly {
                tokenIn := shr(96, calldataload(path.offset))
                tokenOut := shr(96, calldataload(add(path.offset, 22)))
            }
            amountIn = swapKTXExactIn(tokenIn, tokenOut, amountIn, payer, currentReceiver);
            assembly {
                path.offset := add(path.offset, 22)
                path.length := sub(path.length, 22)
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
}
