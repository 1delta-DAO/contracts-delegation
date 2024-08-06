// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {ExoticSwapper} from "./Exotic.sol";

// solhint-disable max-line-length

/**
 * @title Base swapper contract
 * @notice Contains basic logic for swap executions with DEXs
 */
abstract contract BalancerSwapper is ExoticSwapper {
    // all swaps go through the balancer vault
    address internal constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    uint256 internal constant MAX_SINGLE_LENGTH_BALANCER_V2 = 77;
    uint256 internal constant SKIP_LENGTH_BALANCER_V2 = 55; // = 20+1+1+32

    /** Call queryBatchSwap on the Balancer V2 vault.
     *  Should be avoided if possible as it executes (but reverts) state changes in the balancer vault
     *  Executes `call` and therefore is non-view
     *  Will allow to save a refund transfer since we calculate the exact amount
     *  Since we check slippage manually, the concerns mentioned in https://docs.balancer.fi/reference/contracts/query-functions.html
     *  do not apply.
     */
    function _getBalancerAmountIn(bytes32 pId, address tokenIn, address tokenOut, uint256 amountOut) internal returns (uint256 amountIn) {
        assembly {
            let ptr := mload(0x40)
            // call query batch swap
            mstore(ptr, 0xf84d066e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), 1)
            mstore(add(ptr, 0x24), 0xe0)
            mstore(add(ptr, 0x44), 0x1e0) // FundManagement struct
            mstore(add(ptr, 0x64), 0) // sender
            mstore(add(ptr, 0x84), 0) // fromInternalBalance
            mstore(add(ptr, 0xA4), 0) // recipient
            mstore(add(ptr, 0xC4), 0) // toInternalBalance
            mstore(add(ptr, 0xE4), 1)
            mstore(add(ptr, 0x104), 0x20) // SingleSwap struct
            mstore(add(ptr, 0x124), pId) // poolId
            mstore(add(ptr, 0x144), 0) // userDataLength
            mstore(add(ptr, 0x164), 1) // swapKind = GIVEN_OUT
            mstore(add(ptr, 0x184), amountOut) // amount
            mstore(add(ptr, 0x1A4), 0xa0)
            mstore(add(ptr, 0x1C4), 0)
            mstore(add(ptr, 0x1E4), 2)
            mstore(add(ptr, 0x204), tokenIn) // assetIn
            mstore(add(ptr, 0x224), tokenOut) // assetOut

            if iszero(
                call(
                    gas(),
                    BALANCER_V2_VAULT,
                    0x0,
                    ptr,
                    0x244,
                    ptr,
                    0x60 // return is always array of two, we want the first value
                )
            ) {
                revert(0, 0)
            }
            amountIn := mload(add(ptr, 0x40))
        }
    }

    /** Simple exact input swap with Balancer V2. We assume `userData` in the struct to be empty */
    function _swapBalancerExactIn(uint256 offset, uint256 amountIn, address receiver) internal returns (uint256 amountOut) {
        assembly {
            // fetch swap context
            let tokenOut := shr(96, calldataload(offset))
            let tokenIn := shr(96, calldataload(add(offset, SKIP_LENGTH_BALANCER_V2)))
            let balancerPoolId := shr(96, calldataload(add(offset, 22)))

            let ptr := mload(0x40)

            // approve if neeeded
            if and(calldataload(add(offset, 9)), 0xff) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), BALANCER_V2_VAULT)
                mstore(add(ptr, 0x24), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                pop(call(gas(), tokenIn, 0, ptr, 0x44, ptr, 32))
            }

            // populate call to vault
            mstore(ptr, 0x52bbbe2900000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), 0xe0) // FundManagement struct
            mstore(add(ptr, 0x24), address()) // sender
            mstore(add(ptr, 0x44), 0) // fromInternalBalance
            mstore(add(ptr, 0x64), receiver) // receiver
            mstore(add(ptr, 0x84), 0) // toInternalBalance
            mstore(add(ptr, 0xA4), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // limit
            mstore(add(ptr, 0xC4), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // deadline
            mstore(add(ptr, 0xE4), balancerPoolId)
            mstore(add(ptr, 0x104), 1) // SingleSwap struct
            mstore(add(ptr, 0x124), balancerPoolId) // poolId
            mstore(add(ptr, 0x144), 0) // userDataLength
            mstore(add(ptr, 0x164), 0) // swapKind = GIVEN_IN
            mstore(add(ptr, 0x184), tokenIn) // assetIn
            mstore(add(ptr, 0x1A4), tokenOut) // assetOut
            mstore(add(ptr, 0x1C4), amountIn) // amount
            mstore(add(ptr, 0x1E4), 0xC0) // offest
            mstore(add(ptr, 0x204), 0) // assetIn

            if iszero(
                call(
                    gas(),
                    BALANCER_V2_VAULT,
                    0x0,
                    ptr,
                    0x224,
                    0x0,
                    0x20 // amountOut
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            amountOut := mload(0x0)
        }
    }

    /** call single swap function on Balancer V2 vault */
    function _swapBalancerExactOut(bytes32 pId, address tokenIn, address tokenOut, address receiver, uint256 amountOut, uint256 offset) internal {
        assembly {
            let ptr := mload(0x40)
            // approve if neeeded
            if and(calldataload(add(offset, 9)), 0xff) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), BALANCER_V2_VAULT)
                mstore(add(ptr, 0x24), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                pop(call(gas(), tokenIn, 0, ptr, 0x44, ptr, 32))
            }

            mstore(ptr, 0x52bbbe2900000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), 0xe0) // FundManagement struct
            mstore(add(ptr, 0x24), address()) // sender
            mstore(add(ptr, 0x44), 0) // fromInternalBalance
            mstore(add(ptr, 0x64), receiver) // receiver
            mstore(add(ptr, 0x84), 0) // toInternalBalance
            mstore(add(ptr, 0xA4), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // limit
            mstore(add(ptr, 0xC4), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // deadline
            mstore(add(ptr, 0xE4), pId)
            mstore(add(ptr, 0x104), 1) // swapKind = GIVEN_OUT
            mstore(add(ptr, 0x124), tokenIn) // assetIn
            mstore(add(ptr, 0x144), tokenOut) // assetOut
            mstore(add(ptr, 0x164), amountOut) // amount
            mstore(add(ptr, 0x184), 0xC0) // offest
            mstore(add(ptr, 0x1A4), 0) // userData length

            if iszero(
                call(
                    gas(),
                    BALANCER_V2_VAULT,
                    0x0,
                    ptr,
                    0x1C4,
                    0x0,
                    0x0 // we do not use the return array
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
