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
        BridgeParams memory params;

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
            let oftCmdLength
            let amount
            let requiredValue
            let fee

            asset := shr(96, calldataload(add(currentOffset)))
            fee := shr(128, calldataload(add(currentOffset, 116)))

            composeMsgLength := and(shr(240, calldataload(add(currentOffset, 133))), UINT16_MASK)
            extraOptionsLength := and(shr(240, calldataload(add(currentOffset, 135))), UINT16_MASK)
            amount := and(shr(128, calldataload(add(currentOffset, 60))), UINT128_MASK)
            let isNative := and(NATIVE_FLAG, amount)
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

            let minAmountLD :=
                div(mul(amount, sub(FEE_DENOMINATOR, and(shr(224, calldataload(add(currentOffset, 112))), UINT32_MASK))), FEE_DENOMINATOR)
            let compose

            let ptr := mload(0x40)
            mstore(ptr, 0xcbef2aa900000000000000000000000000000000000000000000000000000000) // sendToken selector
            mstore(add(ptr, 0x04), and(shr(224, calldataload(add(currentOffset, 40))), UINT32_MASK)) // dstEid
            mstore(add(ptr, 0x24), calldataload(add(currentOffset, 44))) // to
            mstore(add(ptr, 0x44), amount) // amountLD
            mstore(add(ptr, 0x64), minAmountLD) // minAmountLD
            mstore(add(ptr, 0x84), 0x160) // extraOptions offset
            mstore(add(ptr, 0xa4), add(0x160, add(extraOptionsLength, 0x20))) // composeMsg offset
            mstore(add(ptr, 0xc4), add(add(0x160, add(extraOptionsLength, 0x20)), add(composeMsgLength, 0x20))) // oftCmd offset
            mstore(add(ptr, 0xe4), fee) // nativeFee
            mstore(add(ptr, 0x104), 0) // lzFee
            mstore(add(ptr, 0x124), shr(96, calldataload(add(currentOffset, 76)))) // refundAddress
            mstore(add(ptr, 0x144), extraOptionsLength) // extraOptions length
            calldatacopy(add(ptr, 0x164), add(currentOffset, 137), extraOptionsLength) // extraOptions
            mstore(add(add(ptr, 0x164), extraOptionsLength), composeMsgLength) // composeMsg length
            calldatacopy(add(add(ptr, 0x184), extraOptionsLength), add(add(currentOffset, 137), extraOptionsLength), composeMsgLength) // composeMsg
            mstore(add(add(add(ptr, 0x184), extraOptionsLength), composeMsgLength), 1) // oftCmd length
            mstore(add(add(add(ptr, 0x1a4), extraOptionsLength), composeMsgLength), and(shr(248, calldataload(add(currentOffset, 132))), UINT8_MASK)) // is bus mode
            // call stargate

            if iszero(call(gas(), shr(96, calldataload(add(currentOffset, 20))), requiredValue, ptr, 0x1c4, 0, xxxx)) { revert(0, xxxx) }
        }

        return currentOffset + 139 + composeMsgLength + extraOptionsLength;
    }
}
