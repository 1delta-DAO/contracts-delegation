// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";

contract SquidRouter is BaseUtils {
    /**
     * @notice Handles SquidRouter bridging operations
     * @dev Decodes gateway and token addresses, then forwards to bridge call handler
     * @dev Refactored to fix the stack too deep issue
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
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

    /**
     * @notice Executes the actual SquidRouter bridge call with encoded parameters
     * @dev Handles variable-length fields for bridgedTokenSymbol, destinationChain, destinationAddress, and payload
     * @param gateway The SquidRouter gateway address
     * @param asset The token to be bridged
     * @param currentOffset Current position in the calldata
     * @return ptr Updated calldata offset after processing
     * @custom:calldata-offset-table
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
     * | 61           | sl             | bridgedTokenSymbol                         |
     * | 61+sl        | dl             | destinationChain                           |
     * | 61+sl+dl     | al             | destinationAddress                         |
     * | 61+sl+dl+al  | pl             | payload                                    |
     */
    function _squidRouterBridgeCall(address gateway, address asset, uint256 currentOffset) private returns (uint256 ptr) {
        assembly {
            ptr := mload(0x40)
            {
                let firstThenAmount := calldataload(currentOffset)
                let symbolLen := shr(240, firstThenAmount)
                let destLen := shr(240, shl(16, firstThenAmount))
                let contractAddrLen := shr(240, shl(32, firstThenAmount))
                let payloadLen := shr(240, shl(48, firstThenAmount))
                firstThenAmount := shr(128, shl(64, firstThenAmount))

                let nativeAmount := shr(128, calldataload(add(currentOffset, 24)))
                if gt(nativeAmount, selfbalance()) {
                    mstore(0x00, INSUFFICIENT_VALUE)
                    revert(0x00, 0x04)
                }
                let gasRefundRecipient := calldataload(add(currentOffset, 40))
                let enableExpress := and(UINT8_MASK, shr(88, gasRefundRecipient))
                gasRefundRecipient := shr(96, gasRefundRecipient)

                // set and store amount
                switch firstThenAmount
                // zero-> selfbalance
                case 0 {
                    mstore(0x00, ERC20_BALANCE_OF)
                    mstore(0x04, address())
                    pop(staticcall(gas(), asset, 0x00, 0x24, 0x00, 0x20))
                    mstore(add(ptr, 128), mload(0x00))
                }
                // provided amount
                default { mstore(add(ptr, 128), firstThenAmount) }

                mstore(ptr, symbolLen)
                mstore(add(ptr, 32), destLen)
                mstore(add(ptr, 64), contractAddrLen)
                mstore(add(ptr, 96), payloadLen)
                // mstore(add(ptr, 128), amount)
                mstore(add(ptr, 160), nativeAmount)
                mstore(add(ptr, 192), gasRefundRecipient)
                mstore(add(ptr, 224), enableExpress)

                currentOffset := add(currentOffset, 61)
            }

            // offsets (for strings and bytes)
            let off1
            let off2
            let off3
            let off4
            let total
            {
                // zero padding length
                let padLen1 := and(add(mload(ptr), 31), not(31))
                let padLen2 := and(add(mload(add(ptr, 32)), 31), not(31))
                let padLen3 := and(add(mload(add(ptr, 64)), 31), not(31))
                let padLen4 := and(add(mload(add(ptr, 96)), 31), not(31))

                // offsets (for strings and bytes)
                off1 := 224 // 7 args, 7 * 32 = 224
                off2 := add(off1, add(32, padLen1))
                off3 := add(off2, add(32, padLen2))
                off4 := add(off3, add(32, padLen3))

                // 4 (selector) + 224 head + dynamic sections (padded lengths + 128)
                total := add(356, add(add(padLen1, padLen2), add(padLen3, padLen4)))
            }

            mstore(add(ptr, 256), 0x2147796000000000000000000000000000000000000000000000000000000000)
            let head := add(ptr, 260)

            // head (7 args)
            mstore(head, off1)
            mstore(add(head, 32), mload(add(ptr, 128))) // amount
            mstore(add(head, 64), off2)
            mstore(add(head, 96), off3)
            mstore(add(head, 128), off4)
            mstore(add(head, 160), mload(add(ptr, 192))) // gasRefundRecipient
            mstore(add(head, 192), mload(add(ptr, 224))) // enableExpress

            function copyTo(_head, _at, offs, currOffs) -> newOffs {
                let p := add(_head, offs)
                let l := mload(_at)
                mstore(p, l)
                calldatacopy(add(p, 32), currOffs, l)
                newOffs := add(currOffs, l)
            }

            // bridgedTokenSymbol
            currentOffset := copyTo(head, ptr, off1, currentOffset)

            // destinationChain
            currentOffset := copyTo(head, add(ptr, 32), off2, currentOffset)

            // destinationAddress
            currentOffset := copyTo(head, add(ptr, 64), off3, currentOffset)

            // payload
            currentOffset := copyTo(head, add(ptr, 96), off4, currentOffset)

            mstore(0x40, add(add(ptr, 256), total))

            if iszero(call(gas(), gateway, mload(add(ptr, 160)), add(ptr, 256), total, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            // set ptr to offset as return value
            ptr := currentOffset
        }
    }
}
