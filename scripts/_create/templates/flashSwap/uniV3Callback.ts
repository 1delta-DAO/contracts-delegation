
export const templateUniV3 = (
    ffFactoryAddressContants: string,
    switchCaseContent: string,
    ffFactoryAddressContantsIzumi: string,
    switchCaseContentIzumi: string,
    hasOverride: boolean,
    overrideData?: string
) => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {ValidatorLib} from "../../../../swappers/callbacks/ValidatorLib.sol";
import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";
import {V3Callbacker} from "../../../../swappers/callbacks/V3Callbacker.sol";

/**
 * @title Uniswap V3 type callback implementations
 */
abstract contract UniV3Callbacks is V3Callbacker, Masks, DeltaErrors {
    // factory ff addresses
    ${ffFactoryAddressContants}
    ${ffFactoryAddressContantsIzumi}

    /**
     * Generic UniswapV3 callback executor
     * The call looks like
     * function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {...}
     *
     * Izumi deviates from this, we handle these below if it is deployed on this chain
     */
    function _executeUniV3IfSelector(bytes32 selector) internal {
        bytes32 codeHash;
        bytes32 ffFactoryAddress;
        // we use the amount to pay as shorthand here to 
        // allow paying without added calldata 
        uint256 amountToPay;
        assembly {
            switch selector
            ${switchCaseContent}
            ${switchCaseContentIzumi ? `
            // SELECTOR_IZI_XY
            case 0x1878068400000000000000000000000000000000000000000000000000000000 {
                ${switchCaseContentIzumi}
                amountToPay := calldataload(4)
            }
            // SELECTOR_IZI_YX
            case 0xd3e1c28400000000000000000000000000000000000000000000000000000000 {
                ${switchCaseContentIzumi}
                amountToPay := calldataload(36)
            }
        }`: "}"}

        if (ValidatorLib._hasData(ffFactoryAddress)) {
            uint256 calldataLength;
            address callerAddress;
            address tokenIn;
            assembly {
                ${hasOverride ? overrideContent(overrideData!) : defaultContent()}
                // get original caller address
                callerAddress := shr(96, calldataload(132))
            }
            clSwapCallback(amountToPay, tokenIn, callerAddress, calldataLength);
            // force return
            assembly {
                return(0, 0)
            }
        }
    }
}

`

function overrideContent(data: string) {
    return `
        let ptr
        let pool
        tokenIn := shr(96, calldataload(152))
        let tokenOutAndFee := calldataload(172)
        let tokenOut := shr(96, tokenOutAndFee)
        // if the lower bytes are populated, execute the override validation
        // via a staticcall or Solady clone calculation instead of
        // a standard address computation
        // this is sometimes needed if the factory deploys different
        // pool contracts or something like immutableClone is used
        switch and(FF_ADDRESS_COMPLEMENT, ffFactoryAddress) 
        case 0 {
            let s := mload(0x40)
            mstore(s, ffFactoryAddress)
            let p := add(s, 21)
            // Compute the inner hash in-place
            switch lt(tokenIn, tokenOut)
            case 0 {
                mstore(p, tokenOut)
                mstore(add(p, 32), tokenIn)
            }
            default {
                mstore(p, tokenIn)
                mstore(add(p, 32), tokenOut)
            }
            switch and(FF_ADDRESS_COMPLEMENT, ffFactoryAddress)
            case 0 {
                // cases with fee
                mstore(add(p, 64), and(UINT16_MASK, shr(72, tokenOutAndFee)))
                mstore(p, keccak256(p, 96))
            }
            default {
                // cases without fee, e.g. algebra case
                mstore(p, keccak256(p, 64))
            }
            p := add(p, 32)
            mstore(p, codeHash)

            pool := and(ADDRESS_MASK, keccak256(s, 85))
        }
        default {
            ${data}    
        }

        calldataLength := and(UINT16_MASK, shr(56, tokenOutAndFee))
        ////////////////////////////////////////////////////
        // If the caller is not the calculated pool, we revert
        ////////////////////////////////////////////////////

        if xor(pool, caller()) {
            mstore(0x0, BAD_POOL)
            revert(0x0, 0x4)
        }
    
    `
}

function defaultContent() {
    return `
                tokenIn := shr(96, calldataload(152))
                let tokenOutAndFee := calldataload(172)
                let tokenOut := shr(96, tokenOutAndFee)
                let s := mload(0x40)
                mstore(s, ffFactoryAddress)
                let p := add(s, 21)
                // Compute the inner hash in-place
                switch lt(tokenIn, tokenOut)
                case 0 {
                    mstore(p, tokenOut)
                    mstore(add(p, 32), tokenIn)
                }
                default {
                    mstore(p, tokenIn)
                    mstore(add(p, 32), tokenOut)
                }

                switch and(FF_ADDRESS_COMPLEMENT, ffFactoryAddress)
                case 0 {
                    // cases with fee
                    mstore(add(p, 64), and(UINT16_MASK, shr(72, tokenOutAndFee)))
                    mstore(p, keccak256(p, 96))
                }
                default {
                    // cases without fee, e.g. algebra case
                    mstore(p, keccak256(p, 64))
                }
                p := add(p, 32)
                mstore(p, codeHash)

                ////////////////////////////////////////////////////
                // If the caller is not the calculated pool, we revert
                ////////////////////////////////////////////////////
                if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }

                calldataLength := and(UINT16_MASK, shr(56, tokenOutAndFee))
    `
}