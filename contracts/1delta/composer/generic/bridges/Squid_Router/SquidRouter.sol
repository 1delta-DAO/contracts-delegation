// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";

contract SquidRouter is BaseUtils {
    /**
     * @notice Handles SquidRouter bridging operations
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     *
     * Generic layout:
     * | Offset | Length (bytes) | Description                                |
     * |--------|----------------|--------------------------------------------|
     * | 0      | 20             | gateway                                    |
     * | 20     | 20             | token to be bridged                        |
     */
    function _bridgeSquidRouter(uint256 currentOffset) internal returns (uint256) {
        address gateway;
        address asset;

        assembly {
            gateway := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            asset := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }

        return _squidRouterBridgeCall(gateway, asset, currentOffset);
    }

    /*
     *
     * | Offset       | Length (bytes) | Description                                |
     * |--------------|----------------|--------------------------------------------|
     * | 0            | 2              | bridgedTokenSymbol.length: sl              |
     * | 2            | 2              | destinationChain.length: dl                |
     * | 4            | 2              | destinationAddress.length: al              |
     * | 6            | 2              | payload.length: pl                         |
     * | 8            | 16             | amount                                     |
     * | 24           | 16             | nativeAmount                               |
     * | 40           | 20             | gasRefundRecipient                         |
     * | 60           | 1              | enableExpress                              |
     * | 61           | s1             | bridgedTokenSymbol                         |
     * | 61+s1        | dl             | destinationChain                           |
     * | 61+s1+dl     | al             | destinationAddress                         |
     * | 61+s1+dl+al  | pl             | payload                                    |
     */
    function _squidRouterBridgeCall(address gateway, address asset, uint256 currentOffset) private returns (uint256) {
        assembly {
            if lt(mload(0x40), 0x300) { mstore(0x40, 0x300) }
            {
                let first := calldataload(currentOffset)
                let symbolLen := shr(240, first)
                let destLen := shr(240, shl(16, first))
                let contractAddrLen := shr(240, shl(32, first))
                let payloadLen := shr(240, shl(48, first))
                let amount := shr(128, shl(64, first))

                let nativeAmount := shr(128, calldataload(add(currentOffset, 24)))
                if gt(nativeAmount, selfbalance()) {
                    mstore(0x00, INSUFFICIENT_VALUE)
                    revert(0x00, 0x04)
                }
                let gasRefundRecipient := calldataload(add(currentOffset, 40))
                let enableExpress := and(UINT8_MASK, shr(88, gasRefundRecipient))
                gasRefundRecipient := shr(96, gasRefundRecipient)

                // set and store amount
                switch amount
                // zero-> selfbalance
                case 0 {
                    mstore(0x00, ERC20_BALANCE_OF)
                    mstore(0x04, address())
                    pop(staticcall(gas(), asset, 0x00, 0x24, 0x00, 0x20))
                    mstore(0x100, mload(0x00))
                }
                // provided amount
                default { mstore(0x100, amount) }

                mstore(0x80, symbolLen)
                mstore(0xA0, destLen)
                mstore(0xC0, contractAddrLen)
                mstore(0xE0, payloadLen)
                // mstore(0x100, amount)
                mstore(0x120, nativeAmount)
                mstore(0x140, gasRefundRecipient)
                mstore(0x160, enableExpress)

                currentOffset := add(currentOffset, 61)
            }

            // zero padding length
            let padLen1 := and(add(mload(0x80), 31), not(31))
            let padLen2 := and(add(mload(0xA0), 31), not(31))
            let padLen3 := and(add(mload(0xC0), 31), not(31))
            let padLen4 := and(add(mload(0xE0), 31), not(31))

            // offsets (for strings and bytes)
            let off1 := 224 // 7 args, 7 * 32 = 224
            let off2 := add(off1, add(32, padLen1))
            let off3 := add(off2, add(32, padLen2))
            let off4 := add(off3, add(32, padLen3))

            // 4 (selector) + 224 head + dynamic sections (padded lengths + 128)
            let total := add(356, add(add(padLen1, padLen2), add(padLen3, padLen4)))

            let ptr := mload(0x40)
            mstore(ptr, 0x2147796000000000000000000000000000000000000000000000000000000000)
            let head := add(ptr, 4)

            // head (7 args)
            mstore(add(head, 0), off1)
            mstore(add(head, 32), mload(0x100)) // amount
            mstore(add(head, 64), off2)
            mstore(add(head, 96), off3)
            mstore(add(head, 128), off4)
            mstore(add(head, 160), mload(0x140)) // gasRefundRecipient
            mstore(add(head, 192), mload(0x160)) // enableExpress

            // bridgedTokenSymbol
            {
                let p := add(head, off1)
                let l := mload(0x80)
                mstore(p, l)
                calldatacopy(add(p, 32), currentOffset, l)
                currentOffset := add(currentOffset, l)
            }

            // destinationChain
            {
                let p := add(head, off2)
                let l := mload(0xA0)
                mstore(p, l)
                calldatacopy(add(p, 32), currentOffset, l)
                currentOffset := add(currentOffset, l)
            }

            // destinationAddress
            {
                let p := add(head, off3)
                let l := mload(0xC0)
                mstore(p, l)
                calldatacopy(add(p, 32), currentOffset, l)
                currentOffset := add(currentOffset, l)
            }

            // payload
            {
                let p := add(head, off4)
                let l := mload(0xE0)
                mstore(p, l)
                calldatacopy(add(p, 32), currentOffset, l)
                currentOffset := add(currentOffset, l)
            }

            mstore(0x40, add(ptr, total))

            if iszero(call(gas(), gateway, mload(0x120), ptr, total, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        return currentOffset;
    }
}
