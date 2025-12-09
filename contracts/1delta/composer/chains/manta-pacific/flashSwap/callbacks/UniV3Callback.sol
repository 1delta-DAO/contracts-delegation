// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
import {ValidatorLib} from "../../../../swappers/callbacks/ValidatorLib.sol";
import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";
import {V3Callbacker} from "../../../../swappers/callbacks/V3Callbacker.sol";

/**
 * @title Uniswap V3 type callback implementations
 */
abstract contract UniV3Callbacks is V3Callbacker, Masks, DeltaErrors {
    // factory ff addresses

    bytes32 private constant UNISWAP_V3_FF_FACTORY = 0xff06D830e15081f65923674268121FF57Cc54e4e230000000000000000000000;
    bytes32 private constant UNISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant IZUMI_FF_FACTORY = 0xff8c7d3063579BdB0b90997e18A770eaE32E1eBb080000000000000000000000;
    bytes32 private constant IZUMI_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

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
            case 0xfa461e3300000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := UNISWAP_V3_FF_FACTORY
                codeHash := UNISWAP_V3_CODE_HASH

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }

            // SELECTOR_IZI_XY
            case 0x1878068400000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := IZUMI_FF_FACTORY
                codeHash := IZUMI_CODE_HASH

                amountToPay := calldataload(4)
            }
            // SELECTOR_IZI_YX
            case 0xd3e1c28400000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := IZUMI_FF_FACTORY
                codeHash := IZUMI_CODE_HASH

                amountToPay := calldataload(36)
            }
        }

        if (ValidatorLib._hasData(ffFactoryAddress)) {
            uint256 calldataLength;
            address callerAddress;
            address tokenIn;
            assembly {
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

