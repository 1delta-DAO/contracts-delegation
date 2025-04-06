// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {DodoV2ReferencesBase} from "./DodoV2References.sol";
import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";
import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";

/**
 * @title Contract Module for general Margin Trading on an borrow delegation compatible Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract DodoV2Callbacks is DodoV2ReferencesBase, ERC20Selectors, Masks, DeltaErrors {
    /** selector _REGISTRY(address,address,uint256) - a mapping base->quote->index->pool */
    bytes32 private constant REGISTRY = 0xbdeb0a9100000000000000000000000000000000000000000000000000000000;

    function _validateAndExecuteDodoCall(address sender, address factory, uint256 baseAmount, uint256 quoteAmount) internal {
        uint256 amountToPay;
        uint256 amountReceived;
        address callerAddress;
        uint256 calldataLength;
        uint256 amountStored;
        assembly {
            // revert if sender param is not this address
            if xor(sender, address()) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }

            // caller
            callerAddress := shr(96, calldataload(164))

            /** the tokens are used to validate the callback */

            // base token
            let base := shr(96, calldataload(184))
            // quote token
            let quote := shr(96, calldataload(204))

            let ptr := mload(0x40)
            mstore(ptr, REGISTRY)
            mstore(add(ptr, 4), base)
            mstore(add(ptr, 36), quote)
            amountStored := calldataload(224)
            calldataLength := and(UINT16_MASK, shr(112, amountStored))
            // store index
            mstore(add(ptr, 68), and(UINT16_MASK, shr(136, amountStored)))

            /**
             * This call runs out of gas if the entry does not exist
             * due to `invalid opcode` (that is because they use immutable clones)
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
            amountStored := shr(144, amountStored)

            switch gt(baseAmount, 0)
            case 1 {
                amountReceived := baseAmount
                amountToPay := amountStored
            }
            default {
                amountReceived := quoteAmount
                amountToPay := amountStored
            }
        }
        _deltaComposeInternal(
            callerAddress,
            amountToPay,
            amountReceived,
            // the naive offset is 164
            // we skip the entire callback validation data
            // that is tokens (+40), index (+2), caller (+20), datalength (+2) + amount (14)
            // = 242
            242,
            calldataLength
        );
    }

    /**
     * Generic executor for dodoV2 callbacks
     * Dodo can have 3 selectors as callbacks, we switch case thorugh them here
     */
    function _executeDodoV2IfSelector(bytes32 selector) internal {
        bool isDodo;
        address factoryAddress;
        assembly {
            switch selector
            // DVMFlashLoanCall()
            case 0xeb2021c300000000000000000000000000000000000000000000000000000000 {
                factoryAddress := DVM_FACTORY
                isDodo := 1
            }
            // DSPFlashLoanCall
            case 0xd5b9979700000000000000000000000000000000000000000000000000000000 {
                factoryAddress := DSP_FACTORY
                isDodo := 1
            }
            // DPPFlashLoanCall
            case 0x7ed1f1dd00000000000000000000000000000000000000000000000000000000 {
                factoryAddress := DPP_FACTORY
                isDodo := 1
            }
        }
        if (isDodo) {
            // since we now know it is dodo,
            // we can proceed with validaiton and parameter loading
            address sender;
            uint256 amount0;
            uint256 amount1;
            assembly {
                sender := calldataload(4)
                amount0 := calldataload(36)
                amount1 := calldataload(68)
            }
            _validateAndExecuteDodoCall(sender, factoryAddress, amount0, amount1);
            // force return
            assembly {
                return(0, 0)
            }
        }
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
