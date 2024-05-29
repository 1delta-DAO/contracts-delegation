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
    uint256 internal constant MINIMUM_PATH_LENGTH = 42;

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
    function swapExactIn(uint256 amountIn, address receiver, address payer, bytes calldata path) internal returns (uint256 amountOut) {
        address currentReceiver = address(this);
        uint256 identifier;
        assembly {
            identifier := and(shr(80, calldataload(path.offset)), UINT8_MASK)
        }
        // uniswapV3 style
        if (identifier < 50) {
            if(path.length < 46) currentReceiver = receiver;
            amountIn = _swapUniswapV3PoolExactIn(
                currentReceiver,
                payer,
                int256(amountIn),
                path[:44] // we do not need end flags
            );
            path = path[24:];
        }
        // uniswapV2 style
        else if (identifier < 100) {
            if(path.length < 44) currentReceiver = receiver;
            amountIn = swapUniV2ExactInComplete(
                amountIn,
                currentReceiver,
                payer,
                false,
                path[:41]
            );
            path = path[22:];
        }
        // iZi
        else if (identifier == 100) {
            if(path.length < 46) currentReceiver = receiver;
            amountIn = _swapIZIPoolExactIn(
                currentReceiver,
                payer,
                uint128(amountIn),
                path[:44]
            );
            path = path[24:];
        }
        // WOO Fi
        else if (identifier == 101) {
            if(path.length < 44) currentReceiver = receiver;
            address tokenIn;
            address tokenOut;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord)
                tokenOut := shr(96, calldataload(add(path.offset, 22)))
            }
            amountIn = swapWooFiExactIn(tokenIn, tokenOut, amountIn, receiver, payer);
            path = path[21:];
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
            path = path[23:];
        }
        // Moe LB
        else if (identifier == 103) {
            if(path.length < 46) currentReceiver = receiver;
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
                currentReceiver,
                payer,
                bin
            );
            path = path[24:];
        } else if(identifier == 104) {
            if(path.length < 44) currentReceiver = receiver;
            address tokenIn;
            address tokenOut;
            assembly {
                tokenIn := shr(96, calldataload(path.offset))
                tokenOut := shr(96, calldataload(add(path.offset, 22)))
            }
            amountIn = swapKTXExactIn(tokenIn, tokenOut, amountIn, receiver, payer);
            path = path[22:];
        } 
        // Curve stable general
        else if (identifier == 105) {
            uint8 indexIn;
            uint8 indexOut;
            address pool;
            assembly {
                let indexData := calldataload(add(path.offset, 21))
                indexIn := and(shr(240, indexData), UINT8_MASK)
                indexOut := and(shr(232, indexData), UINT8_MASK)
                pool := and(shr(72, indexData), ADDRESS_MASK)
            }
            amountIn = swapCurveGeneral(indexIn, indexOut, pool, amountIn);
            path = path[44:];
        } else
            revert invalidDexId();
        
        // decide whether to continue or terminate
        if (path.length > 30) {
            // the payer in this case is always this contract
            return swapExactIn(amountIn, receiver, address(this), path);
        } else return amountIn;
    }
}
