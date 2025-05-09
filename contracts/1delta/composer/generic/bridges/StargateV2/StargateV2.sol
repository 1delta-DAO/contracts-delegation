// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";
import "./IStargate.sol";

contract StargateV2 is BaseUtils {
    /**
     * @notice Handles Stargate V2 bridging operations
     * @dev Decodes calldata and forwards the call to the appropriate Stargate adapter function
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     *
     * | Offset       | Length (bytes) | Description                  |
     * |--------------|----------------|------------------------------|
     * | 0            | 20             | tokenAddress                 |
     * | 20           | 20             | stargate pool                |
     * | 40           | 4              | dstEid                       |
     * | 44           | 32             | receiver                     |
     * | 76           | 20             | refundReceiver               |
     * | 96           | 16             | amount                       |
     * | 112          | 4              | slippage                     |
     * | 116          | 16             | fee                          |
     * | 132          | 1              | isBusMode                    |
     * | 133          | 2              | composeMsg.length: cl        |
     * | 135          | 2              | extraOptions.length: el      |
     * | 137          | cl             | composeMsg                   |
     * | 137+cl       | el             | extraOptions                 |
     */
    function _bridgeStargateV2(uint256 currentOffset) internal returns (uint256) {
        assembly {
            function revertWith(code) {
                mstore(0, code)
                revert(0, 4)
            }

            function getBalance(token) -> b {
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                pop(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20))
                b := mload(0x0)
            }

            let asset
            let composeMsgLength
            let extraOptionsLength
            let amount
            let requiredValue
            let fee
            let isNative
            let minAmountLD

            asset := shr(96, calldataload(currentOffset))
            fee := and(shr(128, calldataload(add(currentOffset, 116))), UINT128_MASK)

            composeMsgLength := and(shr(240, calldataload(add(currentOffset, 133))), UINT16_MASK)
            extraOptionsLength := and(shr(240, calldataload(add(currentOffset, 135))), UINT16_MASK)
            amount := and(shr(128, calldataload(add(currentOffset, 96))), UINT128_MASK)
            isNative := and(NATIVE_FLAG, amount)
            // clear the native flag
            amount := and(amount, not(NATIVE_FLAG))

            // check if amount is 0
            switch iszero(amount)
            case 1 {
                switch isNative
                case 1 {
                    // amount is the balance minus the fee
                    amount := sub(selfbalance(), fee)
                    // and value to send is everything
                    requiredValue := selfbalance()
                }
                default {
                    // use token balance
                    amount := getBalance(asset)
                    // value to send is just the fee
                    requiredValue := fee
                    // check if fee is enough
                    if gt(requiredValue, selfbalance()) { revertWith(INSUFFICIENT_VALUE) }
                }
            }
            default {
                switch isNative
                case 1 {
                    // value to send is amount desired plus fee
                    requiredValue := add(amount, fee)
                }
                default {
                    // erc20 case: value is just the fee
                    requiredValue := fee
                }
                // check if we have enough to pay the fee
                if gt(requiredValue, selfbalance()) { revertWith(INSUFFICIENT_VALUE) }
            }

            minAmountLD := div(mul(amount, sub(FEE_DENOMINATOR, and(shr(224, calldataload(add(currentOffset, 112))), UINT32_MASK))), FEE_DENOMINATOR)

            // Set up function call memory
            let ptr := mload(0x40)
            // sendToken selector: 0xcbef2aa9
            mstore(ptr, 0xcbef2aa900000000000000000000000000000000000000000000000000000000)

            // sendParam struct
            mstore(add(ptr, 0x04), 0x60)
            let sendParamSize := add(add(352, extraOptionsLength), composeMsgLength) // the oftCmd is considered in the 352

            // MessagingFee struct
            mstore(add(ptr, 0x24), add(0x60, sendParamSize))

            // refund address
            mstore(add(ptr, 0x44), shr(96, calldataload(add(currentOffset, 76))))

            // sendParam struct
            mstore(add(ptr, 0x64), and(shr(224, calldataload(add(currentOffset, 40))), UINT32_MASK))
            mstore(add(ptr, 0x84), calldataload(add(currentOffset, 44)))
            mstore(add(ptr, 0xA4), amount)
            mstore(add(ptr, 0xC4), minAmountLD)

            let sendParamRelativeOffset := 0xE0

            // extraOptions offset (relative to struct start)
            mstore(add(ptr, 0xE4), sendParamRelativeOffset)
            sendParamRelativeOffset := add(sendParamRelativeOffset, add(extraOptionsLength, 0x20)) // add 1 word for extraOptions length

            // composeMsg offset (relative to struct start)
            mstore(add(ptr, 0x104), sendParamRelativeOffset)
            sendParamRelativeOffset := add(sendParamRelativeOffset, add(composeMsgLength, 0x20)) // add 1 word for composeMsg length

            // oftCmd offset (relative to struct start)
            mstore(add(ptr, 0x124), sendParamRelativeOffset)

            // extraOptions
            let extraOptionsPtr := add(ptr, 0x144)
            mstore(extraOptionsPtr, extraOptionsLength)
            if gt(extraOptionsLength, 0) {
                calldatacopy(add(extraOptionsPtr, 0x20), add(add(currentOffset, 137), composeMsgLength), extraOptionsLength)
            }

            // composeMsg
            let composeMsgPtr := add(add(extraOptionsPtr, 0x20), extraOptionsLength)
            mstore(composeMsgPtr, composeMsgLength)
            if gt(composeMsgLength, 0) { calldatacopy(add(composeMsgPtr, 0x20), add(currentOffset, 137), composeMsgLength) }

            // oftCmd
            let oftCmdPtr := add(add(composeMsgPtr, 0x20), composeMsgLength)
            mstore(oftCmdPtr, 0x20)
            mstore(add(oftCmdPtr, 0x20), and(shr(248, calldataload(add(currentOffset, 132))), UINT8_MASK))

            // MessagingFee struct
            let messagingFeePtr := add(oftCmdPtr, 0x40)
            // nativeFee
            mstore(messagingFeePtr, fee)
            // lzTokenFee
            mstore(add(messagingFeePtr, 0x20), 0)

            let callSize := sub(add(messagingFeePtr, 0x40), ptr)

            // Update free memory pointer
            mstore(0x40, add(ptr, callSize))

            if iszero(call(gas(), shr(96, calldataload(add(currentOffset, 20))), requiredValue, ptr, callSize, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            currentOffset := add(add(add(currentOffset, 137), composeMsgLength), extraOptionsLength)
        }

        return currentOffset;
    }
}
