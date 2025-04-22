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

    bytes32 private constant METROPOLIS_V2_FF_FACTORY = 0xff1570300e9cFEC66c9Fb0C8bc14366C86EB170Ad00000000000000000000000;
    bytes32 private constant METROPOLIS_V2_CODE_HASH = 0xb174fb9703cd825ac38ca3cf781a2750d5ee57f4268806e0bca9bcd3d74b67b5;

    bytes32 private constant SWAPX_V2_FF_FACTORY = 0xff05c1be79d3aC21Cc4B727eeD58C9B2fF757F56630000000000000000000000;
    bytes32 private constant SWAPX_V2_CODE_HASH = 0x6c45999f36731ff6ab43e943fca4b5a700786bbb202116cf6633b32039161e05;

    bytes32 private constant SHADOW_V2_FF_FACTORY = 0xff2dA25E7446A70D7be65fd4c053948BEcAA6374c80000000000000000000000;
    bytes32 private constant SHADOW_V2_CODE_HASH = 0x4ed7aeec7c0286cad1e282dee1c391719fc17fe923b04fb0775731e413ed3554;

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
            case 0xd1f6317800000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := METROPOLIS_V2_FF_FACTORY
                codeHash := METROPOLIS_V2_CODE_HASH
            }
            case 0x9a7bff7900000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                switch or(eq(forkId, 131), eq(forkId, 195))
                case 1 {
                    ffFactoryAddress := SHADOW_V2_FF_FACTORY
                    codeHash := SHADOW_V2_CODE_HASH
                }
                default {
                    switch or(eq(forkId, 136), eq(forkId, 200))
                    case 1 {
                        ffFactoryAddress := SWAPX_V2_FF_FACTORY
                        codeHash := SWAPX_V2_CODE_HASH
                    }
                    default { revert(0, 0) }
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

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
