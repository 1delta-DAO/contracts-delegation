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
    bytes32 private constant REGISTRY = 0xbdeb0a9100000000000000000000000000000000000000000000000000000000;

    constructor() {}

    // Dodo V2 DVM
    function DVMFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount, //
        bytes calldata
    ) external {
        _validateDodoCall(sender, DVM_FACTORY, baseAmount, quoteAmount);
    }

    // Dodo V2 DPP
    function DPPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount, //
        bytes calldata
    ) external {
        _validateDodoCall(sender, DPP_FACTORY, baseAmount, quoteAmount);
    }

    // Dodo V2 DSP
    function DSPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount, //
        bytes calldata
    ) external {
        _validateDodoCall(sender, DSP_FACTORY, baseAmount, quoteAmount);
    }

    function _validateDodoCall(address sender, address factory, uint256 baseAmount, uint256 quoteAmount) private {
        address quote;
        address base;
        address callerAddress;
        uint256 calldataLength;
        uint256 amountStored;
        assembly {
            // revert if sender param is not this address
            if xor(sender, address()) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }

            let firstWord := calldataload(164)
            //caller
            callerAddress := shr(96, firstWord)
            firstWord := calldataload(184)
            // base token
            base := shr(96, firstWord)
            firstWord := calldataload(204)
            // quote token
            quote := shr(96, firstWord)

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
        }
        _dodoCallback(baseAmount, quoteAmount, amountStored, callerAddress, calldataLength);
    }

    function _dodoCallback(
        uint256 baseAmount,
        uint256 quoteAmount, //
        uint256 amountStored,
        address callerAddress,
        uint256 calldataLength
    ) private {
        uint256 amountToPay;
        uint256 amountReceived;
        assembly {
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

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
