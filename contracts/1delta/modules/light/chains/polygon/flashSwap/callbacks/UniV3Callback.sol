// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
import {ValidatorLib} from "../../../../swappers/callbacks/ValidatorLib.sol";
import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";
import {V3Callbacker} from "../../../../../light/swappers/callbacks/V3Callbacker.sol";

/**
 * @title Uniswap V3 type callback implementations
 */
abstract contract UniV3Callbacks is V3Callbacker, Masks, DeltaErrors {
    // factory ff addresses

    bytes32 private constant UNISWAP_V3_FF_FACTORY = 0xff1F98431c8aD98523631AE4a59f267346ea31F9840000000000000000000000;
    bytes32 private constant UNISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant SUSHISWAP_V3_FF_FACTORY = 0xff917933899c6a5F8E37F31E19f92CdBFF7e8FF0e20000000000000000000000;
    bytes32 private constant SUSHISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant RETRO_FF_FACTORY = 0xff91e1B99072f238352f59e58de875691e20Dc19c10000000000000000000000;
    bytes32 private constant RETRO_CODE_HASH = 0x817e07951f93017a93327ac8cc31e946540203a19e1ecc37bc1761965c2d1090;

    bytes32 private constant QUICKSWAP_V3_FF_FACTORY = 0xff2D98E2FA9da15aa6dC9581AB097Ced7af697CB920000000000000000000000;
    bytes32 private constant QUICKSWAP_V3_CODE_HASH = 0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4;

    bytes32 private constant HOLIVERSE_FF_FACTORY = 0xff0b643D3A5903ED89921b85c889797dd9887125Ad0000000000000000000000;
    bytes32 private constant HOLIVERSE_CODE_HASH = 0xb3fc09be5eb433d99b1ec89fd8435aaf5ffea75c1879e19028aa2414a14b3c85;

    bytes32 private constant IZUMI_FF_FACTORY = 0xffcA7e21764CD8f7c1Ec40e651E25Da68AeD0960370000000000000000000000;
    bytes32 private constant IZUMI_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    /**
     * Generic UniswapV3 callback executor
     * The call looks like
     * function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {...}
     *
     * Izumi deviates from this, we handle these below
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
                case 1 {
                    ffFactoryAddress := SUSHISWAP_V3_FF_FACTORY
                    codeHash := SUSHISWAP_V3_CODE_HASH
                }
                case 13 {
                    ffFactoryAddress := RETRO_FF_FACTORY
                    codeHash := RETRO_CODE_HASH
                }
                default { revert(0, 0) }
                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0x2c8958f600000000000000000000000000000000000000000000000000000000 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 0 {
                    ffFactoryAddress := QUICKSWAP_V3_FF_FACTORY
                    codeHash := QUICKSWAP_V3_CODE_HASH
                }
                case 28 {
                    ffFactoryAddress := HOLIVERSE_FF_FACTORY
                    codeHash := HOLIVERSE_CODE_HASH
                }
                default { revert(0, 0) }
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
                calldataLength := and(UINT16_MASK, shr(56, tokenOutAndFee))
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
                // this stores the fee
                mstore(add(p, 64), and(UINT16_MASK, shr(72, tokenOutAndFee)))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, codeHash)

                ////////////////////////////////////////////////////
                // If the caller is not the calculated pool, we revert
                ////////////////////////////////////////////////////
                if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }
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
