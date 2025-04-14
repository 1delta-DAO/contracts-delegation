// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************* Author: Achthar | 1delta 
/******************************************************************************/

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

    bytes32 private constant PANCAKESWAP_V2_FF_FACTORY = 0xff02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E0000000000000000000000;
    bytes32 private constant PANCAKESWAP_V2_CODE_HASH = 0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5;

    /**
     * Generic Uniswap v2 style callbck executor
     */
    function _executeUniV2IfSelector(bytes32 selector) internal {
        bytes32 codeHash;
        bytes32 ffFactoryAddress;
        // this is a data strip that contains [tokenOut(20)|forkId(1)|calldataLength(2)|xxx...xxx(9)]
        bytes32 outData;
        assembly {
            outData := calldataload(204)
            switch selector
            case 0x10d1e85c00000000000000000000000000000000000000000000000000000000 {
                switch and(UINT8_MASK, shr(88, outData))
                case 0 {
                    ffFactoryAddress := UNISWAP_V2_FF_FACTORY
                    codeHash := UNISWAP_V2_CODE_HASH
                }
                case 1 {
                    ffFactoryAddress := SUSHISWAP_V2_FF_FACTORY
                    codeHash := SUSHISWAP_V2_CODE_HASH
                }
            }
            case 0x8480081200000000000000000000000000000000000000000000000000000000 {
                switch and(UINT8_MASK, shr(88, outData))
                case 0 {
                    ffFactoryAddress := PANCAKESWAP_V2_FF_FACTORY
                    codeHash := PANCAKESWAP_V2_CODE_HASH
                }
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

                // get tokens
                let tokenIn := shr(96, calldataload(184))
                calldataLength := and(UINT16_MASK, shr(72, outData))
                let tokenOut := shr(96, outData)

                let ptr := mload(0x40)
                switch lt(tokenIn, tokenOut)
                case 0 {
                    mstore(add(ptr, 0x14), tokenIn)
                    mstore(ptr, tokenOut)
                }
                default {
                    mstore(add(ptr, 0x14), tokenOut)
                    mstore(ptr, tokenIn)
                }
                let salt := keccak256(add(ptr, 0x0C), 0x28)

                mstore(ptr, ffFactoryAddress)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), codeHash)

                // verify that the caller is a v2 type pool
                if xor(and(ADDRESS_MASK, keccak256(ptr, 0x55)), caller()) {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }

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
