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
     * | 108    | 16             | FixedFee (in input decimals) |
     * | 124    | 4              | FeePercentage                |
     * | 128    | 4              | destinationChainId           |
     * | 132    | 1              | fromTokenDecimals            |
     * | 133    | 1              | toTokenDecimals              |
     * | 134    | 32             | receiver                     |
     * | 166    | 4              | deadline                     |
     * | 170    | 2              | message.length: msgLen       |
     * | 172    | msgLen         | message                      |
     */
    function _bridgeAcross(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let inputTokenAddress := shr(96, calldataload(add(currentOffset, 40)))

            let amount := shr(128, calldataload(add(currentOffset, 92)))

            // whether to use native is indicated by the flag
            let isNative := and(NATIVE_FLAG, amount)

            // clear the native flag
            amount := and(amount, not(NATIVE_FLAG))

            // get the length as uint16
            let messageLength := shr(240, calldataload(add(currentOffset, 170)))

            let requiredNativeValue := 0

            // Check if amount is zero and handle accordingly
            // zero means self balance
            switch iszero(amount)
            case 1 {
                switch isNative
                case 0 {
                    mstore(0, ERC20_BALANCE_OF)
                    mstore(0x04, address())
                    pop(staticcall(gas(), inputTokenAddress, 0x0, 0x24, 0x0, 0x20))
                    amount := mload(0x0)
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
                        mstore(0, INSUFFICIENT_VALUE)
                        revert(0, 4)
                    }
                    requiredNativeValue := amount
                }
            }
            // ff is the fixed fee here, then it becomes the amount with fixed fee realized
            let ff := shr(128, calldataload(add(currentOffset, 108)))
            switch gt(amount, ff)
            case 1 { ff := sub(amount, ff) }
            default {
                mstore(0, INSUFFICIENT_AMOUNT)
                revert(0, 4)
            }

            let fromTokenDecimals := calldataload(add(currentOffset, 132))
            let toTokenDecimals := and(shr(240, fromTokenDecimals), UINT8_MASK)
            fromTokenDecimals := shr(248, fromTokenDecimals)
            let decimalDiff := sub(toTokenDecimals, fromTokenDecimals)

            let outputAmount := 0

            let decimalAdjustment := 1

            if xor(fromTokenDecimals, toTokenDecimals) {
                // abs(decimalDiff)
                let mask := sar(255, decimalDiff)
                let absDiff := sub(xor(decimalDiff, mask), mask)

                switch absDiff
                // shorthands
                case 12 { decimalAdjustment := 1000000000000 }
                case 11 { decimalAdjustment := 100000000000 }
                case 10 { decimalAdjustment := 10000000000 }
                case 9 { decimalAdjustment := 1000000000 }
                case 8 { decimalAdjustment := 100000000 }
                case 7 { decimalAdjustment := 10000000 }
                case 6 { decimalAdjustment := 1000000 }
                // arbitrary loop
                default { for { let i := 0 } lt(i, absDiff) { i := add(i, 1) } { decimalAdjustment := mul(decimalAdjustment, 10) } }
            }

            // calculate percentage fee with decimal adjustment
            switch lt(toTokenDecimals, fromTokenDecimals)
            case 1 {
                outputAmount := div(mul(amount, shr(224, calldataload(add(currentOffset, 124)))), mul(FEE_DENOMINATOR, decimalAdjustment))
                ff := div(ff, decimalAdjustment) // apply decimal adjustment on amount with fixed fee
            }
            // none or output has more decimals
            default {
                outputAmount := div(mul(decimalAdjustment, mul(amount, shr(224, calldataload(add(currentOffset, 124))))), FEE_DENOMINATOR)
                ff := mul(ff, decimalAdjustment) // apply decimal adjustment on amount with fixed fee
            } // also handles the case where decimals are the same

            switch gt(ff, outputAmount)
            case 1 { outputAmount := sub(ff, outputAmount) }
            default {
                mstore(0, INSUFFICIENT_AMOUNT)
                revert(0, 4)
            }

            let ptr := mload(0x40)

            // deposit function selector
            mstore(ptr, 0xad5425c600000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), shr(96, calldataload(add(currentOffset, 20)))) // depositor
            mstore(add(ptr, 0x24), calldataload(add(currentOffset, 134))) // recipient (32 bytes)
            mstore(add(ptr, 0x44), inputTokenAddress) // inputToken
            mstore(add(ptr, 0x64), calldataload(add(currentOffset, 60))) // outputToken (32 bytes)
            mstore(add(ptr, 0x84), amount) // amount
            mstore(add(ptr, 0xa4), outputAmount) // outputAmount
            mstore(add(ptr, 0xc4), shr(224, calldataload(add(currentOffset, 128)))) // destinationChainId
            mstore(add(ptr, 0xe4), 0) // exclusiveRelayer (zero address)
            mstore(add(ptr, 0x104), timestamp()) // quoteTimestamp (block timestamp)
            // fillDeadline (exact deadline)
            mstore(add(ptr, 0x124), shr(224, calldataload(add(currentOffset, 166))))
            mstore(add(ptr, 0x144), 0) // exclusivityDeadline (zero)
            mstore(add(ptr, 0x164), 0x180) // message offset
            mstore(add(ptr, 0x184), messageLength) // message length

            // Handle message
            switch gt(messageLength, 0)
            case 1 {
                // add the message from the calldata
                calldatacopy(add(ptr, 0x1a4), add(currentOffset, 172), messageLength)

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
            currentOffset := add(currentOffset, add(172, messageLength))
        }

        return currentOffset;
    }
}
