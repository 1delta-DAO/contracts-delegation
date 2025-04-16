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

    bytes32 private constant UNISWAP_V3_FF_FACTORY = 0xff75FC67473A91335B5b8F8821277262a13B38c9b30000000000000000000000;
    bytes32 private constant UNISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant DTX_FF_FACTORY = 0xfffCA1AEf282A99390B62Ca8416a68F5747716260c0000000000000000000000;
    bytes32 private constant DTX_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant SWAPSICLE_FF_FACTORY = 0xffb68b27a1c93A52d698EecA5a759E2E4469432C090000000000000000000000;
    bytes32 private constant SWAPSICLE_CODE_HASH = 0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d;

    bytes32 private constant HENJIN_FF_FACTORY = 0xff0d22b434E478386Cd3564956BFc722073B3508f60000000000000000000000;
    bytes32 private constant HENJIN_CODE_HASH = 0x4b9e4a8044ce5695e06fce9421a63b6f5c3db8a561eebb30ea4c775469e36eaf;

    bytes32 private constant PANKO_FF_FACTORY = 0xff7DD105453D0AEf177743F5461d7472cC779e63f70000000000000000000000;
    bytes32 private constant PANKO_CODE_HASH = 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;

    bytes32 private constant IZUMI_FF_FACTORY = 0xff8c7d3063579BdB0b90997e18A770eaE32E1eBb080000000000000000000000;
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
                case 9 {
                    ffFactoryAddress := DTX_FF_FACTORY
                    codeHash := DTX_CODE_HASH
                }
                default { revert(0, 0) }

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0x2c8958f600000000000000000000000000000000000000000000000000000000 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 1 {
                    ffFactoryAddress := SWAPSICLE_FF_FACTORY
                    codeHash := SWAPSICLE_CODE_HASH
                }
                case 2 {
                    ffFactoryAddress := HENJIN_FF_FACTORY
                    codeHash := HENJIN_CODE_HASH
                }
                default { revert(0, 0) }

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0x23a69e7500000000000000000000000000000000000000000000000000000000 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 1 {
                    ffFactoryAddress := PANKO_FF_FACTORY
                    codeHash := PANKO_CODE_HASH
                }
                default { revert(0, 0) }

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            default {
                // check if we do izumi
                switch selector
                // SELECTOR_IZI_XY
                case 0x1878068400000000000000000000000000000000000000000000000000000000 {
                    switch and(UINT8_MASK, shr(88, calldataload(172)))
                    // forkId
                    case 0 {
                        ffFactoryAddress := IZUMI_FF_FACTORY
                        codeHash := IZUMI_CODE_HASH
                    }
                    default { revert(0, 0) }
                    amountToPay := calldataload(4)
                }
                // SELECTOR_IZI_YX
                case 0xd3e1c28400000000000000000000000000000000000000000000000000000000 {
                    switch and(UINT8_MASK, shr(88, calldataload(172)))
                    // forkId
                    case 0 {
                        ffFactoryAddress := IZUMI_FF_FACTORY
                        codeHash := IZUMI_CODE_HASH
                    }
                    default { revert(0, 0) }
                    amountToPay := calldataload(36)
                }
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
