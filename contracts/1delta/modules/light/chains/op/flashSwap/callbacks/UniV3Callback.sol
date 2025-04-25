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

    bytes32 private constant WAGMI_FF_FACTORY = 0xffC49c177736107fD8351ed6564136B9ADbE5B1eC30000000000000000000000;
    bytes32 private constant WAGMI_CODE_HASH = 0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb;

    bytes32 private constant VELODROME_V3_FACTORY = 0x000000000000000000000000Cc0bDDB707055e04e497aB22a59c2aF4391cd12F;
    bytes32 private constant VELODROME_V3_IMPLEMENTATION = 0x000000000000000000000000c28aD28853A547556780BEBF7847628501A3bCbb;

    bytes32 private constant DACKIESWAP_V3_FF_FACTORY = 0xffa466ebCfa58848Feb6D8022081f1C21a884889bB0000000000000000000000;
    bytes32 private constant DACKIESWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant ZYBERSWAP_FF_FACTORY = 0xffc0D4323426C709e8D04B5b130e7F059523464a910000000000000000000000;
    bytes32 private constant ZYBERSWAP_CODE_HASH = 0xbce37a54eab2fcd71913a0d40723e04238970e7fc1159bfd58ad5b79531697e7;

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
                case 15 {
                    ffFactoryAddress := WAGMI_FF_FACTORY
                    codeHash := WAGMI_CODE_HASH
                }
                case 19 { ffFactoryAddress := VELODROME_V3_FACTORY }
                default { revert(0, 0) }
                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0x23a69e7500000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := DACKIESWAP_V3_FF_FACTORY
                codeHash := DACKIESWAP_V3_CODE_HASH

                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 { amountToPay := _amount1 }
                default { amountToPay := calldataload(4) }
            }
            case 0x2c8958f600000000000000000000000000000000000000000000000000000000 {
                ffFactoryAddress := ZYBERSWAP_FF_FACTORY
                codeHash := ZYBERSWAP_CODE_HASH

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
                    // this stores the fee
                    mstore(add(p, 64), and(UINT16_MASK, shr(72, tokenOutAndFee)))
                    mstore(p, keccak256(p, 96))
                    p := add(p, 32)
                    mstore(p, codeHash)

                    pool := and(ADDRESS_MASK, keccak256(s, 85))
                }
                default {
                    // Compute Salt
                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        mstore(ptr, tokenOut)
                        mstore(add(ptr, 32), tokenIn)
                    }
                    default {
                        mstore(ptr, tokenIn)
                        mstore(add(ptr, 32), tokenOut)
                    }
                    // this stores the fee
                    mstore(add(ptr, 64), and(UINT16_MASK, shr(72, tokenOutAndFee)))
                    let salt := keccak256(ptr, 96)

                    // get pool by using solady clone calculation
                    mstore(add(ptr, 0x38), VELODROME_V3_FACTORY)
                    mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
                    mstore(add(ptr, 0x14), VELODROME_V3_IMPLEMENTATION)
                    mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
                    mstore(add(ptr, 0x58), salt)
                    mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
                    pool := keccak256(add(ptr, 0x43), 0x55)
                }

                calldataLength := and(UINT16_MASK, shr(56, tokenOutAndFee))
                ////////////////////////////////////////////////////
                // If the caller is not the calculated pool, we revert
                ////////////////////////////////////////////////////

                if xor(pool, caller()) {
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
