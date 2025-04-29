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

    bytes32 private constant SWAPR_V1_FF_FACTORY = 0xff5D48C95AdfFD4B40c1AAADc4e08fc44117E021790000000000000000000000;
    bytes32 private constant SWAPR_V1_CODE_HASH = 0xd306a548755b9295ee49cc729e13ca4a45e00199bbd890fa146da43a50571776;

    bytes32 private constant SUSHISWAP_V2_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
    bytes32 private constant SUSHISWAP_V2_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 private constant HONEYSWAP_FF_FACTORY = 0xffA818b4F111Ccac7AA31D0BCc0806d64F2E0737D70000000000000000000000;
    bytes32 private constant HONEYSWAP_CODE_HASH = 0x3f88503e8580ab941773b59034fb4b2a63e86dbc031b3633a925533ad3ed2b93;

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
            case 0xb527c5d000000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := SWAPR_V1_FF_FACTORY
                codeHash := SWAPR_V1_CODE_HASH
            }
            case 0x10d1e85c00000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))
                switch forkId
                case 1 {
                    ffFactoryAddress := SUSHISWAP_V2_FF_FACTORY
                    codeHash := SUSHISWAP_V2_CODE_HASH
                }
                case 19 {
                    ffFactoryAddress := HONEYSWAP_FF_FACTORY
                    codeHash := HONEYSWAP_CODE_HASH
                }
                default { revert(0, 0) }
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

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
