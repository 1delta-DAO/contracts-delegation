// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";

/**
 * @title Balancer V2 quoter contract
 * @notice Balancer V2 is fun (mostly)
 */
abstract contract BalancerV2Quoter is Masks {
    /**
     *  @notice Call queryBatchSwap on the Balancer V2 vault.
     *  @dev Should be avoided if possible as it executes (but reverts) state changes in the balancer vault
     *  Executes `call` and therefore is non-view
     *  Will allow to save a refund transfer since we calculate the exact amount
     *  Since we check slippage manually, the concerns mentioned in https://docs.balancer.fi/reference/contracts/query-functions.html
     *  do not apply.
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @param currentOffset Current position in the calldata
     * @return amountOut Output amount
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 32             | poolId               |
     * | 32     | 20             | vault                 |
     * | 52     | 1              | payFlag               |
     */
    function _getBalancerAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 currentOffset //
    )
        internal
        returns (uint256 amountOut, uint256)
    {
        assembly {
            let ptr := mload(0x40)
            // balancer vault plus pay flag
            let balancerData := calldataload(add(32, currentOffset))
            let vault := shr(96, balancerData)
            ////////////////////////////////////////////////////
            // call `queryBatchSwap` function on vB2 vault
            // This is not optimal as the call can cost
            // quite some gas for CSPs (~90k), even if we use assembly
            ////////////////////////////////////////////////////
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
            mstore(add(ptr, 0x124), calldataload(currentOffset)) // poolId
            mstore(add(ptr, 0x144), 1) // assetInIndex
            mstore(add(ptr, 0x164), 0) // assetOutIndex
            mstore(add(ptr, 0x184), amountIn) // amount
            mstore(add(ptr, 0x1A4), 0xa0)
            mstore(add(ptr, 0x1C4), 0)
            mstore(add(ptr, 0x1E4), 2)
            mstore(add(ptr, 0x204), tokenIn) // assetIn
            mstore(add(ptr, 0x224), tokenOut) // assetOut

            if iszero(
                call(
                    gas(),
                    vault,
                    0x0,
                    ptr,
                    0x244,
                    ptr,
                    0x80 // return is always array of two, we want the first value
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            amountOut := mload(add(ptr, 0x60))
            balancerData := add(53, currentOffset)
        }
        return (amountOut, currentOffset);
    }
}
