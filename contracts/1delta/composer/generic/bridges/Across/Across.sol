// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IAcross.sol";

contract Across is BaseUtils {
    /**
     * @notice Handles Across bridging operations
     * @dev Decodes calldata and directly executes the bridge operation using assembly
     * @param currentOffset Current position in the calldata
     * @param callerAddress Original caller's address (for possible access control)
     * @return Updated calldata offset after processing
     *
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | spokePool                    |
     * | 20     | 20             | inputTokenAddress               |
     * | 40     | 20             | receivingAssetId             |
     * | 60     | 16             | amount                       |
     * | 76     | 16             | FixedFee                     |
     * | 92     | 4              | FeePercentage                |
     * | 96     | 4              | destinationChainId           |
     * | 100    | 20             | receiver                     |
     * | 120    | 2              | message.length: msgLen       |
     * | 122    | msgLen         | message                      |
     */
    function _bridgeAcross(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        uint256 messageLength;
        assembly {
            // Load key data from calldata
            let inputTokenAddress := shr(96, calldataload(add(currentOffset, 20)))
            let isNative := iszero(inputTokenAddress)
            let amount := and(shr(128, calldataload(add(currentOffset, 60))), UINT128_MASK)
            messageLength := and(shr(240, calldataload(add(currentOffset, 120))), UINT16_MASK)
            let requiredValue := 0
            let outputAmount := 0

            // Check if amount is zero and handle accordingly
            switch iszero(amount)
            case 1 {
                switch isNative
                case 1 {
                    amount := selfbalance()
                    requiredValue := amount
                }
                default {
                    // Get token balance
                    mstore(0x00, ERC20_BALANCE_OF)
                    mstore(0x04, address())
                    if iszero(staticcall(gas(), inputTokenAddress, 0x00, 0x24, 0x00, 0x20)) {
                        mstore(0x00, 0x669567ea00000000000000000000000000000000000000000000000000000000) // ZeroBalance()
                        revert(0, 0x04)
                    }
                    amount := mload(0x00) // return value of the balanceOf call
                }
            }
            // non zero amount
            default {
                if isNative {
                    // For native assets, check enough value was sent
                    if iszero(eq(amount, selfbalance())) {
                        // InsufficientValue error
                        mstore(0x00, 0x1101129400000000000000000000000000000000000000000000000000000000) // InsufficientValue()
                        revert(0x00, 0x04)
                    }
                    requiredValue := amount
                }
            }

            outputAmount := div(mul(amount, sub(1000000000, and(shr(224, calldataload(add(currentOffset, 72))), UINT32_MASK))), 1000000000)

            let ptr := mload(0x40)

            // depositV3 function selector
            mstore(ptr, 0x7b93923200000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), callerAddress) // depositor
            mstore(add(ptr, 0x24), shr(96, calldataload(add(currentOffset, 100)))) // recipient
            mstore(add(ptr, 0x44), inputTokenAddress) // inputToken
            mstore(add(ptr, 0x64), shr(96, calldataload(add(currentOffset, 40)))) // outputToken
            mstore(add(ptr, 0x84), amount) // amount
            mstore(add(ptr, 0xa4), outputAmount) // outputAmount
            mstore(add(ptr, 0xc4), and(shr(224, calldataload(add(currentOffset, 96))), UINT32_MASK)) // destinationChainId
            mstore(add(ptr, 0xe4), 0) // exclusiveRelayer (zero address)
            mstore(add(ptr, 0x104), timestamp()) // quoteTimestamp (block timestamp)
            mstore(add(ptr, 0x124), add(timestamp(), 1800)) // fillDeadline (block timestamp + 30 minutes)
            mstore(add(ptr, 0x144), 0) // exclusivityDeadline (zero address)

            // Handle message
            switch gt(messageLength, 0)
            case 1 {
                mstore(add(ptr, 0x164), add(ptr, 0x184))
                mstore(add(ptr, 0x184), messageLength)

                calldatacopy(add(ptr, 0x1a4), add(currentOffset, 122), messageLength)

                pop(call(gas(), shr(96, calldataload(currentOffset)), requiredValue, ptr, add(0x1a4, messageLength), 0x00, 0x00))

                mstore(0x40, add(ptr, add(0x1c4, messageLength))) // one word after the message
            }
            default {
                // No message
                mstore(add(ptr, 0x164), add(ptr, 0x184))
                mstore(add(ptr, 0x184), 0)

                // Make the call
                pop(call(gas(), shr(96, calldataload(currentOffset)), requiredValue, ptr, 0x1a4, 0x00, 0x00))

                mstore(0x40, add(ptr, 0x1a4)) // one word after the message
            }
        }

        return currentOffset + 122 + messageLength;
    }
}
