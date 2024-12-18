// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {UniTypeSwapper} from "./UniType.sol";

// solhint-disable max-line-length

/**
 * @title Curve swapper contract
 * @notice We do Curve & Fork stuff here
 */
abstract contract CurveSwapper is UniTypeSwapper {

    address internal constant STRATUM_3POOL = 0xD6F312AA90Ad4C92224436a7A4a648d69482e47e;
    address internal constant STRATUM_3POOL_2 = 0x7d3621aCA02B711F5f738C9f21C1bFE294df094d;
    address internal constant STRATUM_ETH_POOL = 0xe8792eD86872FD6D8b74d0668E383454cbA15AFc;

    address internal constant MUSD = 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3;
    address internal constant USDY = 0x5bE26527e817998A7206475496fDE1E68957c5A6;

    constructor() {}

    /**
     * Swaps Stratums Curve fork exact in internally and handles wrapping/unwrapping of mUSD->USDY
     * This one has a dedicated implementation as this pool has a rebasing asset which can be unwrapped
     * The rebasing asset is rarely ever used in other types of swap pools, as such,w e auto wrap / unwrap in case we 
     * use the unwrapped asset as input or output 
     * @param tokenIn input
     * @param tokenOut output
     * @param amountIn sell amount
     * @return amountOut buy amount
     */
    function swapStratum3(
        address tokenIn, 
        address tokenOut, 
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
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(gas(), tokenIn, 0, ptr, 0x64, ptr, 32)

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
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
        
            // curve forks work with indices, we determine these below
            let indexIn
            let indexOut
            switch tokenIn
            // USDY
            case 0x5bE26527e817998A7206475496fDE1E68957c5A6 {

                ////////////////////////////////////////////////////
                // Wrap USDY->mUSD before the swap
                ////////////////////////////////////////////////////

                // execute USDY->mUSD wrap
                // selector for wrap(uint256)
                mstore(0x0, 0xea598c00000000000000000000000000000000000000000000000000000000)
                mstore(0x4, amountIn)
                if iszero(call(gas(), MUSD, 0x0, 0x0, 0x24, 0x0, 0x0)) {
                    returndatacopy(0x0, 0, returndatasize())
                    revert(0x0, returndatasize())
                }

                ////////////////////////////////////////////////////
                // Fetch mUSD balance of this contract 
                ////////////////////////////////////////////////////

                // selector for balanceOf(address)
                mstore(0x0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x04, address())
                
                // call to token
                pop(staticcall(gas(), MUSD, 0x0, 0x24, 0x0, 0x20))

                // load the retrieved balance
                amountIn := mload(0x0)
                indexIn := 0
            }
            // MUSD
            case 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3 {
                indexIn := 0
            }
            // USDC
            case 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9 {
                indexIn := 1
            }
            // USDT
            case 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE {
                indexIn := 2
            }
            default {
                revert(0, 0)
            }

            switch tokenOut
            // USDY
            case 0x5bE26527e817998A7206475496fDE1E68957c5A6 {
                indexOut := 0
            }
            // MUSD
            case 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3 {
                indexOut := 0
            }
            // USDC
            case 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9 {
                indexOut := 1
            }
            // USDT
            case 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE {
                indexOut := 2
            }
            default {
                revert(0, 0)
            }

            ////////////////////////////////////////////////////
            // Execute swap function 
            ////////////////////////////////////////////////////

            // selector for swap(uint8,uint8,uint256,uint256,uint256)
            mstore(ptr, 0x9169558600000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), indexIn)
            mstore(add(ptr, 0x24), indexOut)
            mstore(add(ptr, 0x44), amountIn)
            mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
            mstore(add(ptr, 0x84), MAX_UINT256) // no deadline
            if iszero(call(gas(), STRATUM_3POOL, 0x0, ptr, 0xA4, ptr, 0x20)) {
                returndatacopy(0x0, 0, returndatasize())
                revert(0x0, returndatasize())
            }

            amountOut := mload(ptr)

            if eq(tokenOut, USDY) {

                ////////////////////////////////////////////////////
                // tokenOut is USDY, as such, we unwrap mUSD to SUDY
                ////////////////////////////////////////////////////

                // calculate mUSD->USDY unwrap
                // selector for unwrap(uint256)
                mstore(0x0, 0xde0e9a3e00000000000000000000000000000000000000000000000000000000)
                mstore(0x4, amountOut)
                if iszero(call(gas(), MUSD, 0x0, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0x0, 0, returndatasize())
                    revert(0x0, returndatasize())
                }
                // selector for balanceOf(address)
                mstore(0x0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x4, address())
                // call to token
                pop(staticcall(gas(), USDY, 0x0, 0x24, 0x0, 0x20))
                // load the retrieved balance
                amountOut := mload(0x0)
            }

            ////////////////////////////////////////////////////
            // Send funds to receiver if needed
            ////////////////////////////////////////////////////
            if xor(receiver, address()) {
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amountOut)
                let success := call(gas(), tokenOut, 0, ptr, 0x44, ptr, 32)

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
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
        }
    }

    function swapCurveGeneral(
        uint256 amountIn,
        address payer,
        address receiver,
        uint256 pathOffset
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // Pull funds if needed
            ////////////////////////////////////////////////////
            if xor(payer, address()) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(
                    gas(),
                    shr(96, calldataload(pathOffset)), // tokenIn
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
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
            
            let indexData := calldataload(add(pathOffset, 22))
            let pool := shr(96, indexData)
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
            mstore(add(ptr, 0x84), MAX_UINT256) // no deadline
            if iszero(call(gas(), pool, 0x0, ptr, 0xA4, ptr, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            amountOut := mload(ptr)

            ////////////////////////////////////////////////////
            // Send funds to receiver if needed
            ////////////////////////////////////////////////////
            if xor(receiver, address()) {
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amountOut)
                let success := call(
                    gas(),
                    shr(96, calldataload(add(pathOffset, 44))), // tokenIn, added 2x addr + 4x uint8 
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
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
        }
    }
}
