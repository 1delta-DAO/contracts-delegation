// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IAcross.sol";

contract Across is BaseUtils {
    // Across SpokePool on Arbitrum
    address internal constant SPOKE_POOL = 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A;

    /**
     * @notice Handles Across bridging operations
     * @dev Decodes calldata and directly executes the bridge operation using assembly
     * @param currentOffset Current position in the calldata
     * @param callerAddress Original caller's address (for possible access control)
     * @return Updated calldata offset after processing
     *
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | sendingAssetId               |
     * | 20     | 20             | receivingAssetId             |
     * | 40     | 16             | amount                       |
     * | 56     | 16             | outputAmount                 |
     * | 72     | 4              | destinationChainId           |
     * | 76     | 20             | receiver                     |
     * | 96     | 20             | exclusiveRelayer             |
     * | 116    | 4              | quoteTimestamp               |
     * | 120    | 4              | fillDeadline                 |
     * | 124    | 4              | exclusivityDeadline          |
     * | 128    | 2              | message.length: msgLen       |
     * | 130    | msgLen         | message                      |
     */
    function _bridgeAcross(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        // Local variables to store key data
        address sendingAssetId;
        uint256 amount;
        uint16 messageLength;
        bool isNative;
        uint256 requiredValue;
        bool success;

        assembly {
            // Load sendingAssetId (20 bytes)
            sendingAssetId := shr(96, calldataload(currentOffset))

            // Calculate isNative
            isNative := iszero(sendingAssetId)

            // Load amount (16 bytes)
            amount := and(shr(128, calldataload(add(currentOffset, 40))), UINT128_MASK)

            // Load message length
            messageLength := and(shr(240, calldataload(add(currentOffset, 128))), UINT16_MASK)
        }

        if (amount == 0) {
            if (isNative) {
                amount = address(this).balance;
                requiredValue = amount;
            } else {
                amount = IERC20(sendingAssetId).balanceOf(address(this));
            }
        } else if (isNative) {
            // For native assets, make sure enough value is sent
            if (amount != msg.value) {
                revert InsufficientValue();
            }
            requiredValue = amount;
        }
        assembly {
            // Get free memory pointer for constructing call data
            let ptr := mload(0x40)

            // Store function selector for depositV3
            mstore(ptr, 0x6c571313)

            // Store refundAddress (from calldata offset 96)
            mstore(add(ptr, 0x04), shr(96, calldataload(add(currentOffset, 96))))

            // Store receiver (from calldata offset 76)
            mstore(add(ptr, 0x24), shr(96, calldataload(add(currentOffset, 76))))

            // Store sendingAssetId
            mstore(add(ptr, 0x44), sendingAssetId)

            // Store receivingAssetId (from calldata offset 20)
            mstore(add(ptr, 0x64), shr(96, calldataload(add(currentOffset, 20))))

            // Store amount
            mstore(add(ptr, 0x84), amount)

            // Store outputAmount (from calldata offset 56)
            mstore(add(ptr, 0xA4), and(shr(128, calldataload(add(currentOffset, 56))), UINT128_MASK))

            // Store destinationChainId (from calldata offset 72)
            mstore(add(ptr, 0xC4), and(shr(224, calldataload(add(currentOffset, 72))), UINT32_MASK))

            // Store exclusiveRelayer (from calldata offset 116)
            mstore(add(ptr, 0xE4), shr(96, calldataload(add(currentOffset, 116))))

            // Store quoteTimestamp (from calldata offset 136)
            mstore(add(ptr, 0x104), and(shr(224, calldataload(add(currentOffset, 136))), UINT32_MASK))

            // Store fillDeadline (from calldata offset 140)
            mstore(add(ptr, 0x124), and(shr(224, calldataload(add(currentOffset, 140))), UINT32_MASK))

            // Store exclusivityDeadline (from calldata offset 144)
            mstore(add(ptr, 0x144), and(shr(224, calldataload(add(currentOffset, 144))), UINT32_MASK))

            // Message data handling
            let messageOffset := add(ptr, 0x164)

            // Store message offset (point to the bytes array)
            mstore(messageOffset, 0x20)

            // Store message length
            mstore(add(messageOffset, 0x20), messageLength)

            // Copy message data if there's any
            switch gt(messageLength, 0)
            case 1 {
                calldatacopy(
                    add(messageOffset, 0x40), // destination in memory (after length)
                    add(currentOffset, 150), // source in calldata
                    messageLength // length to copy
                )

                // Round up to multiple of 32 bytes
                let paddedLength := mul(div(add(messageLength, 31), 32), 32)

                // Update free memory pointer
                mstore(0x40, add(add(messageOffset, 0x40), paddedLength))
            }
            default {
                // Update free memory pointer
                mstore(0x40, add(messageOffset, 0x40))
            }

            // Calculate total size of call data
            let callSize := add(0x184, mul(div(add(messageLength, 31), 32), 32))

            // Check if we need to handle token approvals for non-native tokens
            // We'll do this outside the assembly block
        }

        // Check for insufficient value error
        if (requiredValue == 0xFFFFFFFFFFFFFFFF) {
            revert InsufficientValue();
        }

        // For non-native tokens with zero amount, get the token balance
        if (!isNative && amount == 0) {
            amount = IERC20(sendingAssetId).balanceOf(address(this));
        }

        // Handle token approvals for non-native tokens
        if (!isNative && !approvals[sendingAssetId]) {
            SafeERC20.safeIncreaseAllowance(IERC20(sendingAssetId), SPOKE_POOL, type(uint256).max);
            approvals[sendingAssetId] = true;
        }

        // Continue with assembly to make the actual call
        assembly {
            // Get free memory pointer (restored from earlier)
            let ptr := mload(0x40)
            let callSize := add(0x184, mul(div(add(messageLength, 31), 32), 32))

            // Make the call
            success :=
                call(
                    gas(), // forward all gas
                    SPOKE_POOL, // target contract
                    0, // todo: value (0 if not native token)
                    ptr, // input data start
                    callSize, // input data length
                    0, // don't care about output
                    0 // don't care about output length
                )

            // Handle refunds if the call failed
            if iszero(success) {
                // For non-native tokens, we'll handle refund outside assembly

                // Always refund native value if there's any
                if and(gt(requiredValue, 0), isNative) {
                    success :=
                        call(
                            gas(), // forward all gas
                            callerAddress, // refund to caller
                            requiredValue, // refund the value
                            0, // no input data
                            0, // no input data length
                            0, // don't care about output
                            0 // don't care about output length
                        )

                    // Check if refund failed
                    if iszero(success) {
                        mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Error signature
                        mstore(4, 0x20) // String offset
                        mstore(36, 0x0D) // String length (13)
                        mstore(68, 0x526566756e64206661696c6564000000000000000000000000000000000000) // "Refund failed"
                        revert(0, 100) // Revert with error message
                    }
                }
            }
        }

        // Handle refunds for non-native tokens if the call failed
        if (!success && !isNative) {
            SafeERC20.safeTransfer(IERC20(sendingAssetId), callerAddress, amount);
        }

        // Calculate new offset
        return currentOffset + 130 + messageLength;
    }
}
