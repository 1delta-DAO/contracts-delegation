// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {UniTypeSwapper} from "./UniType.sol";

// solhint-disable max-line-length

/**
 * @title Base swapper contract
 * @notice Contains basic logic for swap executions with DEXs
 */
abstract contract CurveSwapper is UniTypeSwapper {

    constructor() {}

    function swapCurveGeneral(
        bytes calldata pathSlice,
        uint256 amountIn,
        address payer,
        address receiver
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // Pull funds if needed
            ////////////////////////////////////////////////////
            if xor(payer, address()) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(
                    gas(),
                    and(
                        ADDRESS_MASK,
                        shr(96, calldataload(pathSlice.offset)) // tokenIn
                    ), 
                    0,
                    ptr,
                    0x64,
                    ptr,
                    32
                )

                let rdsize := returndatasize()

                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            iszero(lt(rdsize, 32)), // at least 32 bytes
                            eq(mload(ptr), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
            
            let indexData := calldataload(add(pathSlice.offset, 22))
            let pool := and(shr(96, indexData), ADDRESS_MASK)
            let indexIn := and(shr(88, indexData), 0xff)
            let indexOut := and(shr(80, indexData), 0xff)
            ////////////////////////////////////////////////////
            // Execute swap function 
            ////////////////////////////////////////////////////

            // selector for swap(uint8,uint8,uint256,uint256,uint256)
            mstore(ptr, 0x9169558600000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), indexIn)
            mstore(add(ptr, 0x24), indexOut)
            mstore(add(ptr, 0x44), amountIn)
            mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
            mstore(add(ptr, 0x84), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // no deadline
            if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                let rdsize := returndatasize()
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }

            amountOut := mload(ptr)

            ////////////////////////////////////////////////////
            // Send funds to receiver if needed
            ////////////////////////////////////////////////////
            if xor(receiver, address()) {
                // selector for transfer(address,uint256)
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amountOut)
                let success := call(
                    gas(),
                    and(
                        ADDRESS_MASK,
                        shr(96, calldataload(add(pathSlice.offset, 44))) // tokenIn, added 2x addr + 4x uint8
                    ), 
                    0,
                    ptr,
                    0x44,
                    ptr,
                    32
                )

                let rdsize := returndatasize()

                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            iszero(lt(rdsize, 32)), // at least 32 bytes
                            eq(mload(ptr), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
        }
    }
}
