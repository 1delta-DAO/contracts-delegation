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

    // lower byte is populated to enter the alternative validation mode
    bytes32 private constant MERCHANT_MOE_FACTORY = 0xff5bEf015CA9424A7C07B68490616a4C1F094BEdEc0000000000000000000001;

    bytes32 private constant CLEOPATRA_V1_FF_FACTORY = 0xffAAA16c016BF556fcD620328f0759252E29b1AB570000000000000000000000;
    bytes32 private constant CLEOPATRA_V1_CODE_HASH = 0xbf2404274de2b11f05e5aebd49e508de933034cb5fa2d0ac3de8cbd4bcef47dc;

    bytes32 private constant VELOCIMETER_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 private constant VELOCIMETER_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;

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
            case 0xba85410f00000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := MERCHANT_MOE_FACTORY
            }
            case 0x9a7bff7900000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                switch or(eq(forkId, 133), eq(forkId, 197))
                case 1 {
                    ffFactoryAddress := VELOCIMETER_FF_FACTORY
                    codeHash := VELOCIMETER_CODE_HASH
                }
                default {
                    switch or(eq(forkId, 135), eq(forkId, 199))
                    case 1 {
                        ffFactoryAddress := CLEOPATRA_V1_FF_FACTORY
                        codeHash := CLEOPATRA_V1_CODE_HASH
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

                let ptr := mload(0x40)
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

                    // calculate pool address in next 4 lines
                    mstore(ptr, ffFactoryAddress)
                    mstore(add(ptr, 0x15), salt)
                    mstore(add(ptr, 0x35), codeHash)
                    pool := and(ADDRESS_MASK, keccak256(ptr, 0x55))
                }
                default {
                    // immutable clone creation code that includes implementation (0x08477e01A19d44C31E4C11Dc2aC86E3BBE69c28B)
                    let tokenIn := shr(96, calldataload(184))
                    let tokenOut := shr(96, outData)
                    mstore(ptr, 0x61005f3d81600a3d39f3363d3d373d3d3d3d61002a806035363936013d730847)
                    mstore(add(ptr, 0x20), 0x7e01a19d44c31e4c11dc2ac86e3bbe69c28b5af43d3d93803e603357fd5bf300)

                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        mstore(add(ptr, 63), shl(96, tokenOut))
                        mstore(add(ptr, 83), shl(96, tokenIn))
                    }
                    default {
                        mstore(add(ptr, 63), shl(96, tokenIn))
                        mstore(add(ptr, 83), shl(96, tokenOut))
                    }
                    // salt are the tokens hashed
                    let salt := keccak256(add(ptr, 63), 0x28)
                    // last part (only the top 2 bytes are needed)
                    mstore(add(ptr, 103), 0x002a000000000000000000000000000000000000000000000000000000000000)
                    let _codeHash := keccak256(ptr, 105)
                    // the factory here starts with ff and puplates the next upper bytes
                    mstore(ptr, MERCHANT_MOE_FACTORY)
                    mstore(add(ptr, 0x15), salt)
                    mstore(add(ptr, 0x35), _codeHash)
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

    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for swap callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
