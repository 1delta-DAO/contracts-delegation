// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../../shared/masks/Masks.sol";

/**
 * @title Balancer V2 swapper contract that uses Symmetric's vault
 * @notice Balancer V2 is fun (mostly)
 */
abstract contract BalancerSwapper is ERC20Selectors, Masks {
    /// @dev Balancer's single swap function
    bytes32 private constant BALANCER_SWAP = 0x52bbbe2900000000000000000000000000000000000000000000000000000000;

    /**
     * Swaps exact input on Balancer V2
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 32             | pool                 |
     * | 32     | 20             | vault                |
     * | 21     | 1              | pay flag             | <- 0: caller pays; 1: contract pays; greater: pre-funded
     */
    function _swapBalancerExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address receiver,
        address callerAddress,
        uint256 currentOffset //
    ) internal returns (uint256 amountOut, uint256 balancerData) {
        assembly {
            balancerData := calldataload(add(32, currentOffset))

            let ptr := mload(0x40)
            if iszero(and(UINT8_MASK, shr(72, balancerData))) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), callerAddress)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(gas(), tokenIn, 0, ptr, 0x64, 0, 32)

                let rdsize := returndatasize()
                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            gt(rdsize, 31), // at least 32 bytes
                            eq(mload(0), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }

            let vault := shr(96, balancerData)

            {
                ////////////////////////////////////////////////////
                // Approve vault if needed
                ////////////////////////////////////////////////////
                mstore(0x0, tokenIn)
                mstore(0x20, 0x1aae13105d9b6581c36534caba5708726e5ea1e03175e823c989a5756966d1f3) // CALL_MANAGEMENT_APPROVALS
                mstore(0x20, keccak256(0x0, 0x40))
                mstore(0x0, vault)
                let key := keccak256(0x0, 0x40)
                // check if already approved
                if iszero(sload(key)) {
                    // selector for approve(address,uint256)
                    mstore(ptr, ERC20_APPROVE)
                    mstore(add(ptr, 0x04), vault)
                    mstore(add(ptr, 0x24), MAX_UINT256)
                    pop(call(gas(), tokenIn, 0, ptr, 0x44, ptr, 32))
                    sstore(key, 1)
                }
            }

            ////////////////////////////////////////////////////
            // Execute swap function on B2 Vault
            ////////////////////////////////////////////////////
            mstore(ptr, BALANCER_SWAP)
            mstore(add(ptr, 0x4), 0xe0) // FundManagement struct
            mstore(add(ptr, 0x24), address()) // sender
            mstore(add(ptr, 0x44), 0) // fromInternalBalance
            mstore(add(ptr, 0x64), receiver) // receiver
            mstore(add(ptr, 0x84), 0) // toInternalBalance
            mstore(add(ptr, 0xA4), 0) // limit
            mstore(add(ptr, 0xC4), MAX_UINT256) // deadline
            mstore(add(ptr, 0xE4), calldataload(currentOffset))
            mstore(add(ptr, 0x104), 0) // swapKind = GIVEN_IN
            mstore(add(ptr, 0x124), tokenIn) // assetIn
            mstore(add(ptr, 0x144), tokenOut) // assetOut
            mstore(add(ptr, 0x164), amountIn) // amount
            mstore(add(ptr, 0x184), 0xC0) // offest
            mstore(add(ptr, 0x1A4), 0) // userData length

            if iszero(
                call(
                    gas(),
                    vault,
                    0x0,
                    ptr,
                    0x1C4,
                    0x0,
                    0x20 // we do not use the return array
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            amountOut := mload(0x0)
            balancerData := add(53, currentOffset)
        }
        return (amountOut, balancerData);
    }
}
