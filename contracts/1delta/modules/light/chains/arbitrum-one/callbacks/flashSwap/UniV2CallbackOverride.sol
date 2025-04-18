// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Contract Module for general Margin Trading on an borrow delegation compatible Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract UniV2CallbackOverride is Masks, DeltaErrors {
    // The uniswapV2 style callback for Ramses V1
    function hook(address, uint256, uint256, bytes calldata) external {
        uint256 calldataLength;
        address callerAddress;
        assembly {
            let outData := calldataload(204)
            // revert if sender param is not this address
            if xor(calldataload(4), address()) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }

            let ptr := mload(0x40)
            // selector for getPair(address,address,bool)
            mstore(ptr, 0x6801cc3000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), shr(96, calldataload(184))) // tokenIn
            mstore(add(ptr, 0x24), shr(96, outData)) // tokenOut
            mstore(add(ptr, 0x34), gt(and(UINT8_MASK, shr(88, outData)), 191))
            // get pair from ramses v2 factory
            pop(staticcall(gas(), 0xAA9B8a7430474119A442ef0C2Bf88f7c3c776F2F, ptr, 0x48, ptr, 0x20))
            // verify that the caller is a v2 type pool
            if xor(mload(ptr), caller()) {
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
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
