// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../../shared/masks/Masks.sol";

/**
 * @title SyncSwap style swapper, pre-funded, all pool variations
 */
abstract contract SyncSwapper is ERC20Selectors, Masks {
    /// @dev selector for swap(bytes,address,address,bytes)
    bytes32 internal constant SYNCSWAP_SELECTOR = 0x7132bb7f00000000000000000000000000000000000000000000000000000000;

    /**
     * @notice Swaps exact input on SyncSwap
     * @dev Pre-funded, all pool variations. Pay flag: 0 = caller pays; 1 = contract pays; greater = pre-funded.
     * @param fromAmount Input amount
     * @param tokenIn Input token address
     * @param receiver Receiver address
     * @param callerAddress Address of the caller
     * @param currentOffset Current position in the calldata
     * @return buyAmount Output amount
     * @return payFlag Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 1              | pay flag             | <- 0: caller pays; 1: contract pays; greater: pre-funded
     */
    function _swapSyncExactIn(
        uint256 fromAmount,
        address tokenIn,
        address receiver,
        address callerAddress,
        uint256 currentOffset //
    )
        internal
        returns (uint256 buyAmount, uint256 payFlag)
    {
        address pool;
        assembly {
            let syncSwapData := calldataload(currentOffset)
            pool := shr(96, syncSwapData)
            payFlag := and(UINT8_MASK, shr(88, syncSwapData))
        }
        // Pre-fund the pool (payMode 0/1). payMode ≥ 2 means pre-funded by a prior op — skip.
        if (payFlag == 0) {
            _safeTransferFrom(tokenIn, callerAddress, pool, fromAmount);
        } else if (payFlag == 1) {
            _safeTransfer(tokenIn, pool, fromAmount);
        }

        assembly {
            let ptr := mload(0x40)
            // selector for swap(...)
            mstore(ptr, SYNCSWAP_SELECTOR)
            mstore(add(ptr, 4), 0x80) // first param set offset
            mstore(add(ptr, 36), 0x0) // sender address
            ////////////////////////////////////////////////////
            // We store the bytes length to zero (no callback)
            // and directly trigger the swap
            ////////////////////////////////////////////////////
            mstore(add(ptr, 68), 0x0) // callback receiver address
            mstore(add(ptr, 100), 0x100) // calldata offset
            mstore(add(ptr, 132), 0x60) // datalength
            mstore(add(ptr, 164), tokenIn) // tokenIn
            mstore(add(ptr, 196), receiver) // to
            mstore(add(ptr, 228), 0) // withdraw mode
            mstore(add(ptr, 260), 0) // path length is zero

            if iszero(
                call(
                    gas(),
                    pool, // pool
                    0x0,
                    ptr, // input selector
                    292, // input size = 292 (selector (4bytes) plus 9*32bytes)
                    ptr, // output
                    0x40 // output size = 0x40
                )
            ) {
                // Forward the error
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            buyAmount := mload(add(ptr, 0x20))
            currentOffset := add(currentOffset, 21)
        }
        return (buyAmount, currentOffset);
    }
}
