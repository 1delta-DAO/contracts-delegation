// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {Masks} from "../../shared/masks/Masks.sol";

/**
 * @title Uniswap V3-style flash loan executor
 * @notice Triggers a real flash loan via `pool.flash(recipient, amount0, amount1, data)` on any
 *         immutable Uniswap-V3-style pool (Classic / Pancake / Algebra / Izumi). Uniswap V3
 *         `flash()` calls back `msg.sender` (this contract), NOT `recipient`, so a pool only ever
 *         re-enters our callback when WE initiated the flash — self-initiation is inherent.
 *         The callback additionally recomputes the pool's CREATE2 address from
 *         (factory, token0, token1, fee) and rejects any caller that is not the deterministic pool.
 * @author 1delta
 * @custom:calldata-offset-table
 * | Offset | Length (bytes) | Description                                              |
 * |--------|----------------|----------------------------------------------------------|
 * | 0      | 1              | forkId (selects factory/codeHash in the callback)        |
 * | 1      | 20             | pool (flash target; validated via CREATE2 in callback)   |
 * | 21     | 20             | tokenIn                                                  |
 * | 41     | 20             | tokenOut                                                 |
 * | 61     | 2              | fee (uint16; ignored for Algebra pools)                 |
 * | 63     | 16             | amount0 (uint128)                                        |
 * | 79     | 16             | amount1 (uint128)                                        |
 * | 95     | 2              | paramsLength (uint16)                                    |
 * | 97     | paramsLength   | params (composeOperations)                              |
 */
contract UniswapV3FlashLoans is Masks {
    function uniswapV3FlashLoan(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let word := calldataload(currentOffset)
            let forkId := shr(248, word) // 1 byte
            let pool := and(ADDRESS_MASK, shr(88, word)) // 20 bytes at +1

            let tokenIn := shr(96, calldataload(add(currentOffset, 21)))
            let tokenOut := shr(96, calldataload(add(currentOffset, 41)))

            let slice := calldataload(add(currentOffset, 61))
            let fee := shr(240, slice) // 2 bytes
            let amount0 := and(UINT128_MASK, shr(112, slice)) // 16 bytes at +63
            // amount1 spans +79..+95
            let amount1 := shr(128, calldataload(add(currentOffset, 79)))
            let paramsLength := shr(240, calldataload(add(currentOffset, 95))) // 2 bytes

            // advance past the fixed header (97 bytes)
            currentOffset := add(currentOffset, 97)

            let ptr := mload(0x40)
            // flash(address recipient,uint256 amount0,uint256 amount1,bytes data)
            mstore(ptr, 0x490e6cbc00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address()) // recipient = self
            mstore(add(ptr, 36), amount0)
            mstore(add(ptr, 68), amount1)
            mstore(add(ptr, 100), 0x80) // offset to `data` (4 head words)
            let dataLength := add(65, paramsLength) // 20+20+20+1+2+2 header + params
            mstore(add(ptr, 132), dataLength)

            // data content starts at ptr+164 (mirrors the callback's calldata offset 132)
            let dp := add(ptr, 164)
            mstore(dp, shl(96, callerAddress)) // [0:20]   origCaller
            mstore(add(dp, 20), shl(96, tokenIn)) // [20:40]  tokenIn
            // [40:65] tokenOut(20) | forkId(1) | fee(2) | paramsLength(2)
            mstore(add(dp, 40), or(or(or(shl(96, tokenOut), shl(88, forkId)), shl(72, fee)), shl(56, paramsLength)))
            // append the compose operations after the 65-byte header
            calldatacopy(add(dp, 65), currentOffset, paramsLength)

            if iszero(
                call(
                    gas(),
                    pool,
                    0x0,
                    ptr,
                    add(164, dataLength), // 4 selector + 5*32 head + data
                    0x0,
                    0x0
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }

            // increment offset past the consumed params
            currentOffset := add(currentOffset, paramsLength)
        }
        return currentOffset;
    }
}
