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
 * @title DodoV2 flash-loan callbacks
 */
abstract contract DodoV2Callbacks is Masks, DeltaErrors {
    address internal constant DVM_FACTORY = 0x0226fCE8c969604C3A0AD19c37d1FAFac73e13c2;
    address internal constant DSP_FACTORY = 0x200D866Edf41070DE251Ef92715a6Ea825A5Eb80;
    address internal constant DPP_FACTORY = 0xc0F9553Df63De5a97Fe64422c8578D0657C360f7;

    /**
     * selector _REGISTRY(address,address,uint256) - a mapping base->quote->index->pool
     */
    bytes32 private constant REGISTRY = 0xbdeb0a9100000000000000000000000000000000000000000000000000000000;

    function _validateAndExecuteDodoCall(address sender, address factory) internal {
        address callerAddress;
        uint256 calldataLength;
        assembly {
            // revert if sender param is not this address
            if xor(sender, address()) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }

            // caller
            callerAddress := shr(96, calldataload(164))

            /**
             * the tokens are used to validate the callback
             */

            // base token
            let base := shr(96, calldataload(184))
            // quote token
            let quote := calldataload(204)

            let ptr := mload(0x40)
            mstore(ptr, REGISTRY)
            mstore(add(ptr, 4), base)
            let amountStored := calldataload(224)
            calldataLength := and(UINT16_MASK, shr(64, quote))
            // store index
            mstore(add(ptr, 68), and(UINT16_MASK, shr(80, quote)))
            // get quote
            quote := shr(96, quote)
            mstore(add(ptr, 36), quote)

            /**
             * This call runs out of gas if the entry does not exist
             * due to invalid opcode (that is because they use immutable clones)
             * We limit the gas for this specific issue.
             */
            if iszero(
                staticcall(
                    10000, // limit the gas here
                    factory,
                    ptr,
                    100, //
                    ptr,
                    0x20
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            if xor(caller(), mload(ptr)) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
        }
        _deltaComposeInternal(
            callerAddress,
            // the naive offset is 164
            // we skip the entire callback validation data
            // that is tokens (+40), index (+2), caller (+20), datalength (+2)
            // = 228
            228,
            calldataLength
        );
    }

    /**
     * Generic executor for dodoV2 callbacks
     * Dodo can have 3 selectors as callbacks, we switch case through them here
     */
    function _executeDodoV2IfSelector(bytes32 selector) internal {
        address factoryAddress;
        assembly {
            switch selector
            // DVMFlashLoanCall()
            case 0xeb2021c300000000000000000000000000000000000000000000000000000000 { factoryAddress := DVM_FACTORY }
            // DSPFlashLoanCall()
            case 0xd5b9979700000000000000000000000000000000000000000000000000000000 { factoryAddress := DSP_FACTORY }
            // DPPFlashLoanCall()
            case 0x7ed1f1dd00000000000000000000000000000000000000000000000000000000 { factoryAddress := DPP_FACTORY }
        }
        if (ValidatorLib._hasAddress(factoryAddress)) {
            // since we now know it is dodo,
            // we can proceed with validation and parameter loading
            address sender;
            assembly {
                sender := calldataload(4)
            }
            _validateAndExecuteDodoCall(sender, factoryAddress);
            // force return
            assembly {
                return(0, 0)
            }
        }
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
