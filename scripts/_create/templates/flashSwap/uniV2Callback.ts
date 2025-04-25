
export const templateUniV2 = (
    ffFactoryAddressContants: string,
    switchCaseContent: string,
    hasOverride: boolean,
    overrideData?: string
) => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
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
    ${ffFactoryAddressContants}
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
            ${switchCaseContent}
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

                ${hasOverride ? overrideContent(overrideData!) : defaultContent()}

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
`

function overrideContent(data: string) {
    return `
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
            mstore(ptr, ffFactoryAddress)
            mstore(add(ptr, 0x15), salt)
            mstore(add(ptr, 0x35), codeHash)
            pool := and(ADDRESS_MASK, keccak256(ptr, 0x55))
        }
        default {
            ${data}    
        }
        // verify that the caller is a v2 type pool
        if xor(pool, caller()) {
            mstore(0x0, BAD_POOL)
            revert(0x0, 0x4)
        }
    
    `
}
function defaultContent() {
    return `
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
                default {
                    salt := keccak256(add(ptr, 0x0C), 0x28)
                }
                mstore(ptr, ffFactoryAddress)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), codeHash)

                // verify that the caller is a v2 type pool
                if xor(and(ADDRESS_MASK, keccak256(ptr, 0x55)), caller()) {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }
    `
}