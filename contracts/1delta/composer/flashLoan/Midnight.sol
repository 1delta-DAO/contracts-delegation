// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {Masks} from "../../shared/masks/Masks.sol";

// solhint-disable max-line-length

/**
 * @title Morpho Midnight flash loans
 * @author 1delta
 * @notice Midnight exposes a multi-token flash loan: `flashLoan(address[] tokens, uint256[] assets, address callback, bytes data)`.
 *         Midnight transfers each `assets[i]` of `tokens[i]` to `callback` (this composer), invokes
 *         `callback.onFlashLoan(msg.sender, tokens, assets, data)`, and then pulls each amount back via
 *         `transferFrom(callback, ...)` - so the batch executed in the callback must leave each borrowed
 *         amount approved to Midnight for repayment (handled by APPROVE compose ops).
 *
 *         The echoed `data` is `callerAddress (20) | poolId (1) | composeOperations`, mirroring the Morpho
 *         Blue flash-loan convention: the trusted caller is prepended here and the leading `poolId` byte is
 *         supplied by the caller as the first byte of `params`.
 */
contract MidnightFlashLoans is Masks {
    /// @dev flashLoan(address[],uint256[],address,bytes)
    bytes32 private constant MIDNIGHT_FLASH_LOAN = 0x4f80fe1000000000000000000000000000000000000000000000000000000000;

    /**
     * @notice Executes a Morpho Midnight multi-token flash loan.
     * @dev We allow ANY midnight-style pool here (target from calldata); the callback validates the
     *      canonical instance for `poolId == 0`.
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset          | Length (bytes) | Description                                   |
     * |-----------------|----------------|-----------------------------------------------|
     * | 0               | 20             | pool (midnight)                               |
     * | 20              | 1              | numTokens (n)                                 |
     * | 21              | n * 36         | per token: token (20) + amount (16, uint128)  |
     * | 21 + n*36       | 2              | paramsLength                                  |
     * | 23 + n*36       | paramsLength   | params (poolId (1) | composeOperations)       |
     */
    function midnightFlashLoan(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // midnight-like pool as target
            let pool := shr(96, calldataload(currentOffset))
            // number of tokens to borrow
            let n := and(UINT8_MASK, shr(248, calldataload(add(currentOffset, 20))))
            // first (token, amount) entry
            let entriesOffset := add(currentOffset, 21)
            // params length follows the n interleaved 36-byte entries
            let paramsLenOffset := add(entriesOffset, mul(n, 36))
            let paramsLength := and(UINT16_MASK, shr(240, calldataload(paramsLenOffset)))
            let paramsOffset := add(paramsLenOffset, 2)

            let ptr := mload(0x40)

            // flashLoan(...)
            mstore(ptr, MIDNIGHT_FLASH_LOAN)
            let base := add(ptr, 4) // ABI head/tail offsets are relative to here

            // head: tokens offset | assets offset | callback | data offset
            let tokensRel := 0x80
            let assetsRel := add(0xa0, mul(n, 0x20)) // 0x80 + 0x20 + n*0x20
            let dataRel := add(assetsRel, add(0x20, mul(n, 0x20)))
            mstore(base, tokensRel)
            mstore(add(base, 0x20), assetsRel)
            mstore(add(base, 0x40), address()) // callback = this composer
            mstore(add(base, 0x60), dataRel)

            // tokens[] and assets[] lengths
            let tokensPos := add(base, tokensRel)
            let assetsPos := add(base, assetsRel)
            mstore(tokensPos, n)
            mstore(assetsPos, n)

            // fill both arrays from the interleaved calldata entries
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let e := add(entriesOffset, mul(i, 36))
                mstore(add(add(tokensPos, 0x20), mul(i, 0x20)), shr(96, calldataload(e))) // token (20 bytes)
                mstore(add(add(assetsPos, 0x20), mul(i, 0x20)), shr(128, calldataload(add(e, 20)))) // amount (16 bytes)
            }

            // data = callerAddress (20) | params (poolId (1) | composeOperations)
            let dataPos := add(base, dataRel)
            let dataLen := add(20, paramsLength)
            mstore(dataPos, dataLen)
            mstore(add(dataPos, 0x20), shl(96, callerAddress)) // caller
            calldatacopy(add(dataPos, 0x34), paramsOffset, paramsLength) // 0x34 = 0x20 + 20

            // zero-pad the data tail up to a word boundary
            let paddedLen := and(add(dataLen, 31), not(31))
            if gt(paddedLen, dataLen) {
                calldatacopy(add(add(dataPos, 0x20), dataLen), calldatasize(), sub(paddedLen, dataLen))
            }

            let size := sub(add(add(dataPos, 0x20), paddedLen), ptr)
            if iszero(call(gas(), pool, 0x0, ptr, size, 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }

            // advance past the consumed params
            currentOffset := add(paramsOffset, paramsLength)
        }
        return currentOffset;
    }
}
