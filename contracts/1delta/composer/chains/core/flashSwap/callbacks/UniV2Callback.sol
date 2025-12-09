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

    bytes32 private constant SHADOW_CORE_FF_FACTORY = 0xff326Ee96748E7DcC04BE1Ef8f4E4F6bdd540489320000000000000000000000;
    bytes32 private constant SHADOW_CORE_CODE_HASH = 0xcfeb1f8754759f0abe461dd409d6d501fdd73b91a848c483faa6db0faf53c3bd;

    bytes32 private constant ARCHERSWAP_FF_FACTORY = 0xffe0b8838e8d73ff1CA193E8cc2bC0Ebf7Cf86F6200000000000000000000000;
    bytes32 private constant ARCHERSWAP_CODE_HASH = 0xa496ce5b8348c4a27befb2616addacbfdd5beaf87f2e951c1f8910fd0d3bf9c0;

    bytes32 private constant SUSHISWAP_V2_FF_FACTORY = 0xffB45e53277a7e0F1D35f2a77160e91e25507f17630000000000000000000000;
    bytes32 private constant SUSHISWAP_V2_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 private constant ICECREAM_V2_FF_FACTORY = 0xff9E6d21E759A7A288b80eef94E4737D313D31c13f0000000000000000000000;
    bytes32 private constant ICECREAM_V2_CODE_HASH = 0x58c1b429d0ffdb4407396ae8118c58fed54898473076d0394163ea2198f7c4a3;

    bytes32 private constant GLYPH_FF_FACTORY = 0xff3E723C7B6188E8Ef638DB9685Af45c7CB66f77B90000000000000000000000;
    bytes32 private constant GLYPH_CODE_HASH = 0xee028118a054757b5daded92bc998b195fc653d33f3214aaabeec98d7599f6b8;

    /**
     * @notice Generic Uniswap V2 style callback executor
     * @dev Validates the callback selector and executes compose operations
     * @param selector The function selector to match
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 4              | selector                     |
     * | 4      | 20             | sender (must be this)        |
     * | 24     | 140            | callbackData                 |
     * | 164    | 20             | callerAddress                |
     * | 184    | 20             | tokenIn                      |
     * | 204    | 20             | tokenOut                     |
     * | 224    | 1              | forkId                       |
     * | 225    | 2              | calldataLength               |
     * | 227    | Variable       | composeOperations            |
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
            case 0x835962f900000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := SHADOW_CORE_FF_FACTORY
                codeHash := SHADOW_CORE_CODE_HASH
            }
            case 0xe4dd2fec00000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := ARCHERSWAP_FF_FACTORY
                codeHash := ARCHERSWAP_CODE_HASH
            }
            case 0x10d1e85c00000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))
                switch forkId
                case 1 {
                    ffFactoryAddress := SUSHISWAP_V2_FF_FACTORY
                    codeHash := SUSHISWAP_V2_CODE_HASH
                }
                case 20 {
                    ffFactoryAddress := ICECREAM_V2_FF_FACTORY
                    codeHash := ICECREAM_V2_CODE_HASH
                }
                default { revert(0, 0) }
            }
            case 0xdf9aee6800000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := GLYPH_FF_FACTORY
                codeHash := GLYPH_CODE_HASH
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
                // calculate pool address in next 4 lines
                mstore(ptr, ffFactoryAddress)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), codeHash)

                // verify that the caller is a v2 type pool
                if xor(and(ADDRESS_MASK, keccak256(ptr, 0x55)), caller()) {
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

    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for swap callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
