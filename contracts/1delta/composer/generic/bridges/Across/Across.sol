// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";

contract Across is BaseUtils {
    /**
     * @notice Handles Across bridging operations
     * @dev Decodes calldata and directly executes the bridge operation using assembly
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     *
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | spokePool                    |
     * | 20     | 20             | depositor                    |
     * | 40     | 20             | inputTokenAddress            |
     * | 60     | 32             | receivingAssetId             |
     * | 92     | 16             | amount                       |
     * | 108    | 16             | FixedFee                     |
     * | 124    | 4              | FeePercentage                |
     * | 128    | 4              | destinationChainId           |
     * | 132    | 32             | receiver                     |
     * | 164    | 2              | message.length: msgLen       |
     * | 166    | msgLen         | message                      |
     */
    function _bridgeAcross(uint256 currentOffset) internal returns (uint256) {
        assembly {
            // Load key data from calldata
            let inputTokenAddress := shr(96, calldataload(add(currentOffset, 40)))

            let amount := and(shr(128, calldataload(add(currentOffset, 92))), UINT128_MASK)

            // whether to use native is indicated by the flag
            let isNative := and(NATIVE_FLAG, amount)

            // clear the native flag
            amount := and(amount, not(NATIVE_FLAG))

            // get the length as uint16
            let messageLength := and(shr(240, calldataload(add(currentOffset, 164))), UINT16_MASK)

            let requiredNativeValue := 0

            // Check if amount is zero and handle accordingly
            // zero means self balance
            switch iszero(amount)
            case 1 {
                switch isNative
                case 0 {
                    // Get token balance
                    mstore(0x00, ERC20_BALANCE_OF)
                    mstore(0x04, address())
                    // unsafe call of balanceOf
                    pop(staticcall(gas(), inputTokenAddress, 0x00, 0x24, 0x00, 0x20))
                    amount := mload(0x00) // return value of the balanceOf call
                }
                default {
                    // get native balance
                    amount := selfbalance()
                    requiredNativeValue := amount
                }
            }
            // non zero amount
            default {
                if isNative {
                    // For native assets, check that hte contract holds enough
                    if gt(amount, selfbalance()) {
                        // InsufficientValue error
                        mstore(0x00, 0x1101129400000000000000000000000000000000000000000000000000000000) // InsufficientValue()
                        revert(0x00, 0x04)
                    }
                    requiredNativeValue := amount
                }
            }

            let outputAmount :=
                div(
                    mul(
                        amount,
                        sub(
                            FEE_DENOMINATOR,
                            and(shr(224, calldataload(add(currentOffset, 124))), UINT32_MASK) // extract the fee from calldata
                        )
                    ),
                    FEE_DENOMINATOR
                )

            let ptr := mload(0x40)

            // deposit function selector
            mstore(ptr, 0xad5425c600000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), shr(96, calldataload(add(currentOffset, 20)))) // depositor
            mstore(add(ptr, 0x24), calldataload(add(currentOffset, 132))) // recipient (32 bytes)
            mstore(add(ptr, 0x44), inputTokenAddress) // inputToken
            mstore(add(ptr, 0x64), calldataload(add(currentOffset, 60))) // outputToken (32 bytes)
            mstore(add(ptr, 0x84), amount) // amount
            mstore(add(ptr, 0xa4), outputAmount) // outputAmount
            mstore(add(ptr, 0xc4), and(shr(224, calldataload(add(currentOffset, 128))), UINT32_MASK)) // destinationChainId
            mstore(add(ptr, 0xe4), 0) // exclusiveRelayer (zero address)
            mstore(add(ptr, 0x104), timestamp()) // quoteTimestamp (block timestamp)
            mstore(add(ptr, 0x124), add(timestamp(), 1800)) // fillDeadline (block timestamp + 30 minutes)
            mstore(add(ptr, 0x144), 0) // exclusivityDeadline (zero address)
            mstore(add(ptr, 0x164), 0x180) // message offset
            mstore(add(ptr, 0x184), messageLength) // message length

            // Handle message
            switch gt(messageLength, 0)
            case 1 {
                // add the message from the calldata
                calldatacopy(add(ptr, 0x1a4), add(currentOffset, 166), messageLength)

                // call and forward error
                if iszero(
                    call(
                        gas(),
                        shr(96, calldataload(currentOffset)), // spoke pool address
                        requiredNativeValue,
                        ptr,
                        add(0x1a4, messageLength), // add length of variable data
                        0x00,
                        0x00
                    )
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                mstore(0x40, add(ptr, add(0x1c4, messageLength))) // one word after the message
            }
            default {
                // call and forward error
                if iszero(
                    call(
                        gas(),
                        shr(96, calldataload(currentOffset)), // spoke pool address
                        requiredNativeValue,
                        ptr,
                        0x1a4,
                        0x00,
                        0x00
                    )
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                mstore(0x40, add(ptr, 0x1a4)) // one word after the message
            }
            currentOffset := add(currentOffset, add(166, messageLength))
        }

        return currentOffset;
    }
}
