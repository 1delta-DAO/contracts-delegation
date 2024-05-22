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
 */
abstract contract BaseSwapper is TokenTransfer, UniTypeSwapper, CurveSwapper, ExoticSwapper {
    error invalidDexId();
    uint256 internal constant MINIMUM_PATH_LENGTH = 47;

    constructor() {}

    /**
     * Get the last token from path calldata
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
    function swapExactIn(uint256 amountIn, address receiver, bytes calldata path) internal returns (uint256 amountOut) {
        address currentReceiver = address(this);
        while (true) {
            uint256 identifier;
            assembly {
                identifier := and(shr(88, calldataload(path.offset)), UINT8_MASK)
            }
             if(path.length < MINIMUM_PATH_LENGTH + 10) currentReceiver = receiver;
            // uniswapV3 style
            if (identifier < 50) {
                amountIn = _swapUniswapV3PoolExactIn(
                    currentReceiver,
                    int256(amountIn),
                    path[:44] // we do not need end flags
                );
                path = path[44:];
            }
            // uniswapV2 style
            else if (identifier < 100) {
                amountIn = swapUniV2ExactInComplete(
                    amountIn,
                    currentReceiver,
                    false,
                    path[:45]
                );
            }
            // iZi
            else if (identifier == 100) {
                amountIn = _swapIZIPoolExactIn(
                    currentReceiver,
                    uint128(amountIn),
                    path[:45]
                );
            }
            // WOO Fi
            else if (identifier == 101) {
                address tokenIn;
                address tokenOut;
                assembly {
                    let firstWord := calldataload(path.offset)
                    tokenIn := shr(96, firstWord)
                    tokenOut := shr(96, calldataload(add(path.offset, 25)))
                }
                amountIn = swapWooFiExactIn(tokenIn, tokenOut, amountIn);
            }
            // Stratum 3USD with wrapper
            else if (identifier == 102) {
                address tokenIn;
                address tokenOut;
                assembly {
                    let firstWord := calldataload(path.offset)
                    tokenIn := shr(96, firstWord)
                    tokenOut := shr(96, calldataload(add(path.offset, 25)))
                }
                amountIn = swapStratum3(tokenIn, tokenOut, amountIn);
            }
            // Moe LB
            else if (identifier == 103) {
                address tokenIn;
                address tokenOut;
                uint24 bin;
                assembly {
                    let firstWord := calldataload(path.offset)
                    tokenIn := shr(96, firstWord)
                    tokenOut := shr(96, calldataload(add(path.offset, 25)))
                    bin := and(shr(64, firstWord), UINT24_MASK)
                }
                amountIn = swapLBexactIn(tokenIn, tokenOut, amountIn, address(this), uint16(bin));
            } else if(identifier == 104) {
                address tokenIn;
                address tokenOut;
                assembly {
                    let firstWord := calldataload(path.offset)
                    tokenIn := shr(96, firstWord)
                    tokenOut := shr(96, calldataload(add(path.offset, 25)))
                }
                amountIn = swapKTXExactIn(tokenIn, tokenOut, amountIn);
            } 
            // Curve stable general
            else if (identifier == 105) {
                uint8 indexIn;
                uint8 indexOut;
                uint8 subGroup;
                assembly {
                    let indexData := and(shr(72, calldataload(path.offset)), UINT24_MASK)
                    indexIn := and(shr(16, indexData), UINT8_MASK)
                    indexOut := and(shr(8, indexData), UINT8_MASK)
                    subGroup := and(indexData, UINT8_MASK)
                }
                amountIn = swapStratumCurveGeneral(indexIn, indexOut, subGroup, amountIn);
            } else
                revert invalidDexId();
            
            // decide whether to continue or terminate
            if (path.length > MINIMUM_PATH_LENGTH) {
                // path = path[25:];
            } else {
                amountOut = amountIn;
                break;
            }
        }
    }
}
