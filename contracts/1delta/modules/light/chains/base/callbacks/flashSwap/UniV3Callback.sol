
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************* Author: Achthar | 1delta 
/******************************************************************************/

import {ValidatorLib} from "../../../../swappers/callbacks/ValidatorLib.sol";
import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";
import {ERC20Selectors} from "../../../../../shared/selectors/ERC20Selectors.sol";

/**
 * @title Uniswap V3 type callback implementations
 */
abstract contract UniV3Callbacks is ERC20Selectors, Masks, DeltaErrors {
    // factory ff addresses
    
            bytes32 private constant UNISWAP_V3_FF_FACTORY = 0xff33128a8fC17869897dcE68Ed026d694621f6FDfD0000000000000000000000;
            bytes32 private constant UNISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
           
            bytes32 private constant SUSHISWAP_V3_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
            bytes32 private constant SUSHISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
           
            bytes32 private constant SOLIDLY_V3_FF_FACTORY = 0xff70Fe4a44EA505cFa3A57b95cF2862D4fd5F0f6870000000000000000000000;
            bytes32 private constant SOLIDLY_V3_CODE_HASH = 0xe9b68c5f77858eecac2e651646e208175e9b1359d68d0e14fc69f8c54e5010bf;
           
            bytes32 private constant ALIENBASE_V3_FF_FACTORY = 0xff0Fd83557b2be93617c9C1C1B6fd549401C74558C0000000000000000000000;
            bytes32 private constant ALIENBASE_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
           
            bytes32 private constant BASEX_V3_FF_FACTORY = 0xff38015D05f4fEC8AFe15D7cc0386a126574e8077B0000000000000000000000;
            bytes32 private constant BASEX_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
           
            bytes32 private constant KINETIX_V3_FF_FACTORY = 0xffdDF5a3259a88Ab79D5530eB3eB14c1C92CD97FCf0000000000000000000000;
            bytes32 private constant KINETIX_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
           
            bytes32 private constant AERODROME_SLIPSTREAM_FF_FACTORY = 0xff5e7BB104d84c7CB9B682AaC2F3d509f5F406809A0000000000000000000000;
            bytes32 private constant AERODROME_SLIPSTREAM_CODE_HASH = 0xffb9af9ea6d9e39da47392ecc7055277b9915b8bfc9f83f105821b7791a6ae30;
           
            bytes32 private constant PANCAKESWAP_V3_FF_FACTORY = 0xff41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c90000000000000000000000;
            bytes32 private constant PANCAKESWAP_V3_CODE_HASH = 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;
           
            bytes32 private constant DACKIESWAP_V3_FF_FACTORY = 0xff4f205D69834f9B101b9289F7AFFAc9B77B3fF9b70000000000000000000000;
            bytes32 private constant DACKIESWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
           
    
            bytes32 private constant IZUMI_FF_FACTORY = 0xff8c7d3063579BdB0b90997e18A770eaE32E1eBb080000000000000000000000;
            bytes32 private constant IZUMI_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;
           
    /** This functione xecutes a simple transfer to shortcut the callback if there is no further calldata */
    function clSwapCallback(uint256 amountToPay, address tokenIn, address callerAddress, uint256 calldataLength) private {
        assembly {
            // one can pass no path to continue
            // we then assume the calldataLength as flag to
            // indicate the pay type
            if lt(calldataLength, 2) {
                let ptr := mload(0x40)

                let success
                // transfer from caller
                switch calldataLength
                case 0 {
                    // selector for transferFrom(address,address,uint256)
                    mstore(ptr, ERC20_TRANSFER_FROM)
                    mstore(add(ptr, 0x04), callerAddress)
                    mstore(add(ptr, 0x24), caller())
                    mstore(add(ptr, 0x44), amountToPay)

                    success := call(gas(), tokenIn, 0, ptr, 0x64, ptr, 32)
                }
                // transfer plain
                default {
                    // selector for transfer(address,uint256)
                    mstore(ptr, ERC20_TRANSFER)
                    mstore(add(ptr, 0x04), caller())
                    mstore(add(ptr, 0x24), amountToPay)
                    success := call(
                        gas(),
                        tokenIn, // tokenIn, pool + 5x uint8 (i,j,s,a)
                        0,
                        ptr,
                        0x44,
                        ptr,
                        32
                    )
                }

                let rdsize := returndatasize()

                if iszero(
                    and(
                        success, // call itself succeeded
                        or(
                            iszero(rdsize), // no return data, or
                            and(
                                gt(rdsize, 31), // at least 32 bytes
                                eq(mload(ptr), 1) // starts with uint256(1)
                            )
                        )
                    )
                ) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
                return(0, 0)
            }
        }
        _deltaComposeInternal(
            callerAddress,
            // the naive offset is 132
            // we skip the entire callback validation data
            // that is tokens (+40), fee (+2), caller (+20), forkId (+1) datalength (+2)
            // = 197
            197,
            calldataLength
        );
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
    
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
case 2 {
                ffFactoryAddress := SOLIDLY_V3_FF_FACTORY
                codeHash := SOLIDLY_V3_CODE_HASH

            }
case 3 {
                ffFactoryAddress := ALIENBASE_V3_FF_FACTORY
                codeHash := ALIENBASE_V3_CODE_HASH

            }
case 4 {
                ffFactoryAddress := BASEX_V3_FF_FACTORY
                codeHash := BASEX_V3_CODE_HASH

            }
case 5 {
                ffFactoryAddress := KINETIX_V3_FF_FACTORY
                codeHash := KINETIX_V3_CODE_HASH

            }
case 6 {
                ffFactoryAddress := AERODROME_SLIPSTREAM_FF_FACTORY
                codeHash := AERODROME_SLIPSTREAM_CODE_HASH

            }

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 {
                    amountToPay := _amount1
                }
                default {
                    amountToPay := calldataload(4)
                }
            }
case 0x23a69e7500000000000000000000000000000000000000000000000000000000 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))

    case 0 {
                ffFactoryAddress := PANCAKESWAP_V3_FF_FACTORY
                codeHash := PANCAKESWAP_V3_CODE_HASH

            }
case 1 {
                ffFactoryAddress := DACKIESWAP_V3_FF_FACTORY
                codeHash := DACKIESWAP_V3_CODE_HASH

            }

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 {
                    amountToPay := _amount1
                }
                default {
                    amountToPay := calldataload(4)
                }
            }

            default {
                // check if we do izumi
                switch selector
                // SELECTOR_IZI_XY
                case 0x1878068400000000000000000000000000000000000000000000000000000000 {
                    switch and(UINT8_MASK, shr(88, calldataload(172))) // forkId
                    case 0 {
                ffFactoryAddress := IZUMI_FF_FACTORY
                codeHash := IZUMI_CODE_HASH

            }

                    default {
                        revert(0, 0)
                    }
                    amountToPay := calldataload(4)
                }
                // SELECTOR_IZI_YX
                case 0xd3e1c28400000000000000000000000000000000000000000000000000000000 {
                    switch and(UINT8_MASK, shr(88, calldataload(172))) // forkId
                    case 0 {
                ffFactoryAddress := IZUMI_FF_FACTORY
                codeHash := IZUMI_CODE_HASH

            }

                    default {
                        revert(0, 0)
                    }
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

