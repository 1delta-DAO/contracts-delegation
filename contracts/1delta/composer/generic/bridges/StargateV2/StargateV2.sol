// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";

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
            let minAmountLD

            // underlying (=0 means native)
            asset := shr(96, calldataload(currentOffset))

            // native fee
            fee := shr(128, calldataload(add(currentOffset, 116)))

            // get bytes lenght
            composeMsgLength := shr(240, calldataload(add(currentOffset, 133)))
            extraOptionsLength := shr(240, calldataload(add(currentOffset, 135)))

            amount := shr(128, calldataload(add(currentOffset, 96)))
            // native flag is high bit
            let isNative := and(NATIVE_FLAG, amount)
            // clear the native flag
            amount := and(amount, not(NATIVE_FLAG))

            let slfBal := selfbalance()
            // check if amount is 0
            switch iszero(amount)
            case 1 {
                // native is asset = 0
                switch isNative
                case 0 {
                    // use token balance
                    amount := getBalance(asset)
                    // value to send is just the fee
                    requiredValue := fee
                    // check if fee is enough
                    if gt(requiredValue, slfBal) { revertWith(INSUFFICIENT_VALUE) }
                }
                default {
                    // amount is the balance minus the fee
                    amount := sub(slfBal, fee)
                    // and value to send is everything
                    requiredValue := slfBal
                }
            }
            default {
                // native is asset = 0
                switch isNative
                case 0 {
                    // erc20 case: value is just the fee
                    requiredValue := fee
                }
                default {
                    // value to send is amount desired plus fee
                    requiredValue := add(amount, fee)
                }
                // check if we have enough to pay the fee
                if gt(requiredValue, slfBal) { revertWith(INSUFFICIENT_VALUE) }
            }

            // amount adjusted for slippage
            minAmountLD :=
                div(
                    mul(
                        amount,
                        sub(
                            FEE_DENOMINATOR,
                            shr(224, calldataload(add(currentOffset, 112))) // slippage (assured to not overflow)
                        )
                    ),
                    FEE_DENOMINATOR
                )

            // Set up function call memory
            let ptr := mload(0x40)
            // sendToken selector: 0xcbef2aa9
            mstore(ptr, 0xcbef2aa900000000000000000000000000000000000000000000000000000000)

            // sendParam struct
            mstore(add(ptr, 0x04), 128)

            // nativeFee
            mstore(add(ptr, 0x24), fee)

            // lzTokenFee
            mstore(add(ptr, 0x44), 0)

            // refund address
            mstore(add(ptr, 0x64), shr(96, calldataload(add(currentOffset, 76))))

            // sendParam struct
            mstore(add(ptr, 0x84), shr(224, calldataload(add(currentOffset, 40))))
            mstore(add(ptr, 0xa4), calldataload(add(currentOffset, 44)))
            mstore(add(ptr, 0xc4), amount)
            mstore(add(ptr, 0xe4), minAmountLD)

            // byte offsets
            // extraOptions offset
            mstore(add(ptr, 0x104), 0xe0) // this one is fixed

            // composeMsg offset
            let composeMsgOffset
            switch iszero(extraOptionsLength)
            case 1 { composeMsgOffset := 0x120 }
            case 0 {
                let divResult := div(extraOptionsLength, 32)
                let modResult := mod(extraOptionsLength, 32)
                let numWords
                switch gt(modResult, 0)
                case 1 { numWords := add(divResult, 1) }
                default { numWords := divResult }

                composeMsgOffset := add(0xe0, mul(0x20, add(numWords, 1))) // +1 for the extraOptions's length
            }
            mstore(add(ptr, 0x124), composeMsgOffset)

            // oftCmd offset
            let oftCmdOffset
            switch iszero(composeMsgLength)
            case 1 { oftCmdOffset := add(composeMsgOffset, 0x20) }
            default {
                let divResult := div(composeMsgLength, 32)
                let modResult := mod(composeMsgLength, 32)
                let numWords
                switch gt(modResult, 0)
                case 1 { numWords := add(divResult, 1) }
                default { numWords := divResult }

                oftCmdOffset := add(composeMsgOffset, mul(0x20, add(numWords, 1))) // +1 for the composeMsg's length
            }
            mstore(add(ptr, 0x144), oftCmdOffset)

            // extraOptions
            let extraOptionsPtr := add(ptr, 0x164) // fixed one, relative to ptr
            mstore(extraOptionsPtr, extraOptionsLength)
            if gt(extraOptionsLength, 0) {
                calldatacopy(add(extraOptionsPtr, 0x20), add(add(currentOffset, 137), composeMsgLength), extraOptionsLength)
            }

            // composeMsg
            let composeMsgPtr := add(composeMsgOffset, add(ptr, 0x84))
            mstore(composeMsgPtr, composeMsgLength)
            if gt(composeMsgLength, 0) { calldatacopy(add(composeMsgPtr, 0x20), add(currentOffset, 137), composeMsgLength) }

            let callSize // callsize for calling stargate

            // oftCmd
            let oftCmdPtr := add(oftCmdOffset, add(ptr, 0x84))
            switch iszero(
                shr(248, calldataload(add(currentOffset, 132))) // isTaxiMode flag (already masked)
            )
            case 1 {
                mstore(oftCmdPtr, 0x0)
                callSize := sub(add(oftCmdPtr, 0x20), ptr) // add only length word
            }
            default {
                mstore(oftCmdPtr, 0x20)
                mstore(add(oftCmdPtr, 0x20), 0)

                callSize := sub(add(oftCmdPtr, 0x40), ptr) // add length and busMode flag
            }

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
