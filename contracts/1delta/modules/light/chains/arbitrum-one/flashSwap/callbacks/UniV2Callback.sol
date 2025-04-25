// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
import {ValidatorLib} from "../../../../swappers/callbacks/ValidatorLib.sol";
import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Contract Module for general Margin Trading on an borrow delegation compatible Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract UniV2Callbacks is Masks, DeltaErrors {
    // factories

    bytes32 private constant UNISWAP_V2_FF_FACTORY = 0xfff1D7CC64Fb4452F05c498126312eBE29f30Fbcf90000000000000000000000;
    bytes32 private constant UNISWAP_V2_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 private constant SUSHISWAP_V2_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
    bytes32 private constant SUSHISWAP_V2_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 private constant CAMELOT_V2_FF_FACTORY = 0xff6EcCab422D763aC031210895C81787E87B43A6520000000000000000000000;
    bytes32 private constant CAMELOT_V2_CODE_HASH = 0xa856464ae65f7619087bc369daaf7e387dae1e5af69cfa7935850ebf754b04c1;

    bytes32 private constant PANCAKESWAP_V2_FF_FACTORY = 0xff02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E0000000000000000000000;
    bytes32 private constant PANCAKESWAP_V2_CODE_HASH = 0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5;

    bytes32 private constant APESWAP_FF_FACTORY = 0xffCf083Be4164828f00cAE704EC15a36D7114912840000000000000000000000;
    bytes32 private constant APESWAP_CODE_HASH = 0xae7373e804a043c4c08107a81def627eeb3792e211fb4711fcfe32f0e4c45fd5;

    bytes32 private constant RAMSES_V1_FACTORY = 0x000000000000000000000000AAA20D08e59F6561f242b08513D36266C5A29415;

    /**
     * Generic Uniswap v2 style callbck executor
     */
    function _executeUniV2IfSelector(bytes32 selector) internal {
        bytes32 codeHash;
        bytes32 ffFactoryAddress;
        // this is a data strip that contains [tokenOut(20)|forkId(1)|calldataLength(2)|xxx...xxx(9)]
        bytes32 outData;
        uint256 forkId;
        assembly {
            outData := calldataload(204)
            switch selector
            case 0x10d1e85c00000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))
                switch forkId
                case 0 {
                    ffFactoryAddress := UNISWAP_V2_FF_FACTORY
                    codeHash := UNISWAP_V2_CODE_HASH
                }
                case 1 {
                    ffFactoryAddress := SUSHISWAP_V2_FF_FACTORY
                    codeHash := SUSHISWAP_V2_CODE_HASH
                }
                case 130 {
                    ffFactoryAddress := CAMELOT_V2_FF_FACTORY
                    codeHash := CAMELOT_V2_CODE_HASH
                }
                default { revert(0, 0) }
            }
            case 0x8480081200000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := PANCAKESWAP_V2_FF_FACTORY
                codeHash := PANCAKESWAP_V2_CODE_HASH
            }
            case 0xbecda36300000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := APESWAP_FF_FACTORY
                codeHash := APESWAP_CODE_HASH
            }
            case 0x9a7bff7900000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := RAMSES_V1_FACTORY
            }
        }

        if (ValidatorLib._hasData(ffFactoryAddress)) {
            uint256 calldataLength;
            address callerAddress;
            assembly {
                // revert if sender param is not this address
                if xor(calldataload(4), address()) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }

                let ptr
                let pool
                // if the lower bytes are populated, execute the override validation
                // via a staticcall or Solady clone calculation instead of
                // a standard address computation
                // this is sometimes needed if the factory deploys different
                // pool contracts or something like immutableClone is used
                switch and(FF_ADDRESS_COMPLEMENT, ffFactoryAddress)
                case 0 {
                    // get tokens
                    let tokenIn := shr(96, calldataload(184))
                    let tokenOut := shr(96, outData)

                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        mstore(add(ptr, 0x14), tokenIn)
                        mstore(ptr, tokenOut)
                    }
                    default {
                        mstore(add(ptr, 0x14), tokenOut)
                        mstore(ptr, tokenIn)
                    }
                    let salt
                    // 128 and higher is solidly
                    // 128-130 are reserved for the ones that have no isStable flag
                    switch gt(forkId, 130)
                    case 1 {
                        mstore8(
                            add(ptr, 0x34),
                            gt(forkId, 191) // store isStable (id>=192)
                        )
                        salt := keccak256(add(ptr, 0x0C), 0x29)
                    }
                    default { salt := keccak256(add(ptr, 0x0C), 0x28) }
                    mstore(ptr, ffFactoryAddress)
                    mstore(add(ptr, 0x15), salt)
                    mstore(add(ptr, 0x35), codeHash)
                    pool := and(ADDRESS_MASK, keccak256(ptr, 0x55))
                }
                default {
                    // selector for getPair(address,address,bool)
                    mstore(ptr, 0x6801cc3000000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), shr(96, calldataload(184))) // tokenIn
                    mstore(add(ptr, 0x24), shr(96, outData)) // tokenOut
                    mstore(add(ptr, 0x34), gt(forkId, 191)) // isStable
                    // get pair from ramses v2 factory
                    pop(staticcall(gas(), ffFactoryAddress, ptr, 0x48, ptr, 0x20))
                    pool := mload(ptr)
                }
                // verify that the caller is a v2 type pool
                if xor(pool, caller()) {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }

                calldataLength := and(UINT16_MASK, shr(72, outData))
                // get caller address as provided in the call setup
                callerAddress := shr(96, calldataload(164))
            }
            _deltaComposeInternal(
                callerAddress,
                // the naive offset is 164
                // we skip the entire callback validation data
                // that is tokens (+40), caller (+20), dexId (+1) datalength (+2)
                // = 227
                227,
                calldataLength
            );
            // force return
            assembly {
                return(0, 0)
            }
        }
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
