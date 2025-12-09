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

    bytes32 private constant UNISWAP_V3_FF_FACTORY = 0xff0d922Fb1Bc191F64970ac40376643808b4B74Df90000000000000000000000;
    bytes32 private constant UNISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant METHLAB_FF_FACTORY = 0xff8f140Fc3e9211b8DC2fC1D7eE3292F6817C5dD5D0000000000000000000000;
    bytes32 private constant METHLAB_CODE_HASH = 0xacd26fbb15704ae5e5fe7342ea8ebace020e4fa5ad4a03122ce1678278cf382b;

    bytes32 private constant CRUST_FF_FACTORY = 0xffEaD128BDF9Cff441eF401Ec8D18a96b4A2d252520000000000000000000000;
    bytes32 private constant CRUST_CODE_HASH = 0x55664e1b1a13929bcf29e892daf029637225ec5c85a385091b8b31dcca255627;

    bytes32 private constant AGNI_FF_FACTORY = 0xffe9827B4EBeB9AE41FC57efDdDd79EDddC2EA4d030000000000000000000000;
    bytes32 private constant AGNI_CODE_HASH = 0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a;

    bytes32 private constant BUTTER_FF_FACTORY = 0xffEECa0a86431A7B42ca2Ee5F479832c3D4a4c26440000000000000000000000;
    bytes32 private constant BUTTER_CODE_HASH = 0xc7d06444331e4f63b0764bb53c88788882395aa31961eed3c2768cc9568323ee;

    bytes32 private constant SWAPSICLE_FF_FACTORY = 0xff9dE2dEA5c68898eb4cb2DeaFf357DFB26255a4aaffffffffffffffffffffff;
    bytes32 private constant SWAPSICLE_CODE_HASH = 0x177d5fbf994f4d130c008797563306f1a168dc689f81b2fa23b4396931014d91;

    bytes32 private constant CLEOPATRA_FF_FACTORY = 0xffAAA32926fcE6bE95ea2c51cB4Fcb60836D320C420000000000000000000000;
    bytes32 private constant CLEOPATRA_CODE_HASH = 0x1565b129f2d1790f12d45301b9b084335626f0c92410bc43130763b69971135d;

    bytes32 private constant FUSIONX_V3_FF_FACTORY = 0xff7DD105453D0AEf177743F5461d7472cC779e63f70000000000000000000000;
    bytes32 private constant FUSIONX_V3_CODE_HASH = 0x1bce652aaa6528355d7a339037433a20cd28410e3967635ba8d2ddb037440dbf;

    bytes32 private constant IZUMI_FF_FACTORY = 0xff45e5F26451CDB01B0fA1f8582E0aAD9A6F27C2180000000000000000000000;
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
                switch and(UINT8_MASK, shr(88, calldataload(172)))

                case 0 {
                    ffFactoryAddress := UNISWAP_V3_FF_FACTORY
                    codeHash := UNISWAP_V3_CODE_HASH
                }
                case 10 {
                    ffFactoryAddress := METHLAB_FF_FACTORY
                    codeHash := METHLAB_CODE_HASH
                }
                case 12 {
                    ffFactoryAddress := CRUST_FF_FACTORY
                    codeHash := CRUST_CODE_HASH
                }
                default { revert(0, 0) }
                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0x5bee97a300000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := AGNI_FF_FACTORY
                codeHash := AGNI_CODE_HASH

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0xe5f6c0f800000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := BUTTER_FF_FACTORY
                codeHash := BUTTER_CODE_HASH

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0x2c8958f600000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := SWAPSICLE_FF_FACTORY
                codeHash := SWAPSICLE_CODE_HASH

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0x654b648700000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := CLEOPATRA_FF_FACTORY
                codeHash := CLEOPATRA_CODE_HASH

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0xae067e0f00000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := FUSIONX_V3_FF_FACTORY
                codeHash := FUSIONX_V3_CODE_HASH

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

