// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";
import {AxelarOps} from "contracts/1delta/composer/enums/DeltaEnums.sol";

contract Axelar is BaseUtils {
    /**
     * @notice Handles Axelar bridging operations
     * @dev Decodes calldata and forwards the call to the appropriate Axelar gateway function
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     *
     * Generic layout:
     * | Offset | Length (bytes) | Description                                |
     * |--------|----------------|--------------------------------------------|
     * | 0      | 1              | axelarOperation (AxelarOps)                |
     * | 1      | 20             | gateway                                    |
     * | 21     | 20             | token to be bridged                        |
     */
    function _bridgeAxelar(uint256 currentOffset) internal returns (uint256) {
        uint256 axelarOperation;
        address gateway;
        address asset;

        assembly {
            let first := calldataload(currentOffset)
            axelarOperation := shr(248, first)
            gateway := shr(96, shl(8, first))
            currentOffset := add(currentOffset, 21)
            asset := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
        }

        if (axelarOperation == AxelarOps.CALL_CONTRACT_WITH_TOKEN) {
            return _callContractWithToken(gateway, asset, currentOffset);
        } else if (axelarOperation == AxelarOps.SEND_TOKEN) {
            return _sendToken(gateway, asset, currentOffset);
        } else {
            _invalidOperation();
        }
    }

    /*
     * function bridgeCall(
     *   string calldata bridgedTokenSymbol,
     *   uint256 amount,
     *   string calldata destinationChain,
     *   string calldata destinationAddress,
     *   bytes calldata payload,
     *   address gasRefundRecipient,
     *   bool enableExpress
     * ) external payable
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
            let first := calldataload(currentOffset)
            let symbolLen := shr(240, first)
            let destLen := shr(240, shl(16, first))
            let contractAddrLen := shr(240, shl(32, first))
            let payloadLen := shr(240, shl(48, first))
            let amount := shr(128, shl(64, first))

            let nativeAmount := shr(128, calldataload(add(currentOffset, 24)))
            if gt(nativeAmount, selfbalance()) {
                mstore(0x00, INSUFFICIENT_VALUE) // InsufficientValue()
                revert(0x00, 0x04)
            }
            let gasRefundRecipient := calldataload(add(currentOffset, 40))
            let enableExpress := and(UINT8_MASK, shr(88, gasRefundRecipient))
            gasRefundRecipient := shr(96, gasRefundRecipient)

            currentOffset := add(currentOffset, 61)

            if iszero(amount) {
                mstore(0x00, ERC20_BALANCE_OF)
                mstore(0x04, address())
                pop(staticcall(gas(), asset, 0x00, 0x24, 0x00, 0x20))
                amount := mload(0x00)
            }

            // zero padding length
            let padLen1 := and(add(symbolLen, 31), not(31))
            let padLen2 := and(add(destLen, 31), not(31))
            let padLen3 := and(add(contractAddrLen, 31), not(31))
            let padLen4 := and(add(payloadLen, 31), not(31))

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
            mstore(add(head, 32), amount)
            mstore(add(head, 64), off2)
            mstore(add(head, 96), off3)
            mstore(add(head, 128), off4)
            mstore(add(head, 160), gasRefundRecipient)
            mstore(add(head, 192), enableExpress)

            // bridgedTokenSymbol
            let p := add(head, off1)
            mstore(p, symbolLen)
            calldatacopy(add(p, 32), currentOffset, symbolLen)
            currentOffset := add(currentOffset, symbolLen)

            // destinationChain
            p := add(head, off2)
            mstore(p, destLen)
            calldatacopy(add(p, 32), currentOffset, destLen)
            currentOffset := add(currentOffset, destLen)

            // destinationAddress
            p := add(head, off3)
            mstore(p, contractAddrLen)
            calldatacopy(add(p, 32), currentOffset, contractAddrLen)
            currentOffset := add(currentOffset, contractAddrLen)

            // payload
            p := add(head, off4)
            mstore(p, payloadLen)
            calldatacopy(add(p, 32), currentOffset, payloadLen)
            currentOffset := add(currentOffset, payloadLen)

            mstore(0x40, add(ptr, total))

            if iszero(call(gas(), gateway, nativeAmount, ptr, total, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        return currentOffset;
    }

    /*
     *
     *  | Offset | Length (bytes) | Description                                |
     *  | 0      | 2              | destinationChain.length: dl                |
     *  | 2      | 2              | contractAddress.length: al                 |
     *  | 4      | 2              | payload.length: pl                         |
     *  | 6      | 2              | symbol.length: sl                          |
     *  | 8      | 16             | amount                                     |
     *  | 24     | dl             | destinationChain                           |
     *  | 24+dl  | al             | contractAddress                            |
     *  | ...    | pl             | payload                                    |
     *  | ...    | sl             | symbol                                     |
    */
    function _callContractWithToken(address gateway, address asset, uint256 currentOffset) private returns (uint256) {
        assembly {
            let first := calldataload(currentOffset)
            let destLen := shr(240, first)
            let contractAddrLen := shr(240, shl(16, first))
            let payloadLen := shr(240, shl(32, first))
            let symbolLen := shr(240, shl(48, first))
            let amount := shr(128, shl(64, first))
            currentOffset := add(currentOffset, 24)

            if iszero(amount) {
                mstore(0x00, ERC20_BALANCE_OF)
                mstore(0x04, address())
                pop(staticcall(gas(), asset, 0x00, 0x24, 0x00, 0x20))
                amount := mload(0x00)
            }

            // zero padding length
            let padLen1 := and(add(destLen, 31), not(31))
            let padLen2 := and(add(contractAddrLen, 31), not(31))
            let padLen3 := and(add(payloadLen, 31), not(31))
            let padLen4 := and(add(symbolLen, 31), not(31))

            // offsets (for strings and bytes)
            let off1 := 160 // 5 args, 5 * 32 = 160
            let off2 := add(off1, add(32, padLen1)) // +1 word for length
            let off3 := add(off2, add(32, padLen2))
            let off4 := add(off3, add(32, padLen3))

            // 4 (selector) + 160 head + dynamic sections (32 * 4 + padded lengths = 128)
            let total :=
                add(
                    292, // 164 + 128
                    add(add(padLen1, padLen2), add(padLen3, padLen4))
                )

            let ptr := mload(0x40)
            mstore(ptr, 0xb541708400000000000000000000000000000000000000000000000000000000)
            let head := add(ptr, 4)

            // head (5 args)
            mstore(add(head, 0), off1)
            mstore(add(head, 32), off2)
            mstore(add(head, 64), off3)
            mstore(add(head, 96), off4)
            mstore(add(head, 128), amount)

            // destinationChain
            let p := add(head, off1)
            mstore(p, destLen)
            calldatacopy(add(p, 32), currentOffset, destLen)
            currentOffset := add(currentOffset, destLen)

            // contractAddress
            p := add(head, off2)
            mstore(p, contractAddrLen)
            calldatacopy(add(p, 32), currentOffset, contractAddrLen)
            currentOffset := add(currentOffset, contractAddrLen)

            // payload
            p := add(head, off3)
            mstore(p, payloadLen)
            calldatacopy(add(p, 32), currentOffset, payloadLen)
            currentOffset := add(currentOffset, payloadLen)

            // symbol
            p := add(head, off4)
            mstore(p, symbolLen)
            calldatacopy(add(p, 32), currentOffset, symbolLen)
            currentOffset := add(currentOffset, symbolLen)

            mstore(0x40, add(ptr, total))

            if iszero(call(gas(), gateway, 0, ptr, total, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        return currentOffset;
    }

    /*
     * | Offset  | Length (bytes) | Description                                |
     * | 21      | 2              | destinationChain.length: dl                |
     * | 23      | 2              | destinationAddress.length: al              |
     * | 25      | 2              | symbol.length: sl                          |
     * | 27      | 16             | amount                                     |
     * | 43      | dl             | destinationChain                           |
     * | 43+dl   | al             | destinationAddress                         |
     * | 43+dl+al| sl             | symbol                                     |
     */

    function _sendToken(address gateway, address asset, uint256 currentOffset) private returns (uint256) {
        assembly {
            let first := calldataload(currentOffset)

            let destLen := shr(240, first)
            let addrLen := shr(240, shl(16, first))
            let symbolLen := shr(240, shl(32, first))
            let amount := shr(128, shl(48, first))

            currentOffset := add(currentOffset, 22)

            if iszero(amount) {
                mstore(0x00, ERC20_BALANCE_OF)
                mstore(0x04, address())
                pop(staticcall(gas(), asset, 0x00, 0x24, 0x00, 0x20))
                amount := mload(0x00)
            }

            // zero padding length
            let padLen1 := and(add(destLen, 31), not(31))
            let padLen2 := and(add(addrLen, 31), not(31))
            let padLen3 := and(add(symbolLen, 31), not(31))

            // offsets (for strings)
            let off1 := 128 // 4 args, 4 * 32 = 128
            let off2 := add(off1, add(32, padLen1))
            let off3 := add(off2, add(32, padLen2))

            // 4 (selector) + 128 head (4 args) + 96 (3 dynamic bytes length, 3 * 32) + padded lengths
            let total := add(228, add(add(padLen1, padLen2), padLen3))

            let ptr := mload(0x40)
            mstore(ptr, 0x26ef699d00000000000000000000000000000000000000000000000000000000)
            let head := add(ptr, 4)

            // head (4 args)
            mstore(add(head, 0), off1)
            mstore(add(head, 32), off2)
            mstore(add(head, 64), off3)
            mstore(add(head, 96), amount)

            // destinationChain
            let p := add(head, off1)
            mstore(p, destLen)
            calldatacopy(add(p, 32), currentOffset, destLen)
            currentOffset := add(currentOffset, destLen)

            // destinationAddress
            p := add(head, off2)
            mstore(p, addrLen)
            calldatacopy(add(p, 32), currentOffset, addrLen)
            currentOffset := add(currentOffset, addrLen)

            // symbol
            p := add(head, off3)
            mstore(p, symbolLen)
            calldatacopy(add(p, 32), currentOffset, symbolLen)
            currentOffset := add(currentOffset, symbolLen)

            mstore(0x40, add(ptr, total))

            if iszero(call(gas(), gateway, 0, ptr, total, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        return currentOffset;
    }
}
