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

    bytes32 private constant QUICKSWAP_V3_FF_FACTORY = 0xff7B446Bfb3763Ed0892f08893Eb06Dda79aB28CB9ffffffffffffffffffffff;
    bytes32 private constant QUICKSWAP_V3_CODE_HASH = 0xb3fc09be5eb433d99b1ec89fd8435aaf5ffea75c1879e19028aa2414a14b3c85;

    bytes32 private constant SONEX_V3_FF_FACTORY = 0xff3E4ff8662820E3dec3DACDb66ef1FFad5Dc5Ab830000000000000000000000;
    bytes32 private constant SONEX_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant KYO_V3_FF_FACTORY = 0xff137841043180BBA8EF52828F9030D1b7fE065F950000000000000000000000;
    bytes32 private constant KYO_V3_CODE_HASH = 0xf54c8516b0255aaf493382e8534bab492d4325d4c84374ac39f7fa643a5cfbcd;

    bytes32 private constant VELODROME_V3_FF_FACTORY = 0xff04625B046C69577EfC40e6c0Bb83CDBAfab5a55F0000000000000000000000;
    bytes32 private constant VELODROME_V3_CODE_HASH = 0x7b216153c50849f664871825fa6f22b3356cdce2436e4f48734ae2a926a4c7e5;

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
            case 0x2c8958f600000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := QUICKSWAP_V3_FF_FACTORY
                codeHash := QUICKSWAP_V3_CODE_HASH

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0xfa461e3300000000000000000000000000000000000000000000000000000000 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 1 {
                    ffFactoryAddress := SONEX_V3_FF_FACTORY
                    codeHash := SONEX_V3_CODE_HASH
                }
                case 2 {
                    ffFactoryAddress := KYO_V3_FF_FACTORY
                    codeHash := KYO_V3_CODE_HASH
                }
                case 19 {
                    ffFactoryAddress := VELODROME_V3_FF_FACTORY
                    codeHash := VELODROME_V3_CODE_HASH
                }
                default { revert(0, 0) }
                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
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

