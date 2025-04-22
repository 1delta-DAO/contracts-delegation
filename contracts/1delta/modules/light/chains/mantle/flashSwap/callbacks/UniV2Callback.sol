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

    bytes32 private constant MERCHANT_MOE_FACTORY = 0x0000000000000000000000005bEf015CA9424A7C07B68490616a4C1F094BEdEc;

    bytes32 private constant CLEOPATRA_V1_FF_FACTORY = 0xffAAA16c016BF556fcD620328f0759252E29b1AB570000000000000000000000;
    bytes32 private constant CLEOPATRA_V1_CODE_HASH = 0xbf2404274de2b11f05e5aebd49e508de933034cb5fa2d0ac3de8cbd4bcef47dc;

    bytes32 private constant VELOCIMETER_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 private constant VELOCIMETER_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;

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
            case 0xba85410f00000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := MERCHANT_MOE_FACTORY
            }
            case 0x9a7bff7900000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                if or(eq(forkId, 133), eq(forkId, 197)) {
                    ffFactoryAddress := VELOCIMETER_FF_FACTORY
                    codeHash := VELOCIMETER_CODE_HASH
                }
                {
                    if or(eq(forkId, 135), eq(forkId, 199)) {
                        ffFactoryAddress := CLEOPATRA_V1_FF_FACTORY
                        codeHash := CLEOPATRA_V1_CODE_HASH
                    }
                    {
                        revert(0, 0)
                    }
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

                let ptr
                let pool
                // if the lower bytes are populated, execute the override validation
                // via a staticcall instead of an address computation
                // this is sometimes needed if the factory deploys different
                // pool contracts or something like immutableClone is used
                if and(0xffffffffffffffffffffff, ffFactoryAddress) {
                    // selector for getPair(address,address)
                    mstore(ptr, 0xe6a4390500000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), shr(96, calldataload(184))) // tokenIn
                    mstore(add(ptr, 0x24), shr(96, outData)) // tokenOut
                    // get pair from merchant moe factory
                    pop(staticcall(gas(), ffFactoryAddress, ptr, 0x48, ptr, 0x20))

                    pool := mload(ptr)
                }
                {
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
