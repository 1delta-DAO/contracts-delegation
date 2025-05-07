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
     * | 56     | 16             | FixedFee                     |
     * | 72     | 4              | FeePercentage                |
     * | 76     | 4              | destinationChainId           |
     * | 80     | 20             | receiver                     |
     * | 100    | 2              | message.length: msgLen       |
     * | 102    | msgLen         | message                      |
     */
    function _bridgeAcross(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        uint256 fillDeadlineBuffer = IAcrossSpokePool(SPOKE_POOL).fillDeadlineBuffer();
        uint256 messageLength;
        assembly {
            // Load key data from calldata
            let sendingAssetId := shr(96, calldataload(currentOffset))
            let isNative := iszero(sendingAssetId)
            let amount := and(shr(128, calldataload(add(currentOffset, 40))), UINT128_MASK)
            messageLength := and(shr(240, calldataload(add(currentOffset, 100))), UINT16_MASK)
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
                    if iszero(staticcall(gas(), sendingAssetId, 0x00, 0x24, 0x00, 0x20)) {
                        mstore(0x00, 0x669567ea00000000000000000000000000000000000000000000000000000000) // ZeroBalance()
                        revert(0, 0x04)
                    }
                    amount := mload(0x00) // return value of the balanceOf call
                }
            }
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

            // Prepare call to SPOKE_POOL.depositV3
            let ptr := mload(0x40)

            // depositV3 function selector
            mstore(ptr, 0x7b93923200000000000000000000000000000000000000000000000000000000)

            // Pack parameters for depositV3
            mstore(add(ptr, 0x04), callerAddress) // _depositor
            mstore(add(ptr, 0x24), shr(96, calldataload(add(currentOffset, 80)))) // _recipient
            mstore(add(ptr, 0x44), sendingAssetId) // _originToken
            mstore(add(ptr, 0x64), shr(96, calldataload(add(currentOffset, 20)))) // _destinationToken
            mstore(add(ptr, 0x84), amount) // _amount
            mstore(add(ptr, 0xa4), outputAmount) // _destinationAmount
            mstore(add(ptr, 0xc4), and(shr(224, calldataload(add(currentOffset, 76))), UINT32_MASK)) // _destinationChainId
            mstore(add(ptr, 0xe4), 0) // _relayerFeePct (address(0))
            mstore(add(ptr, 0x104), timestamp()) // _quoteTimestamp
            mstore(add(ptr, 0x124), add(timestamp(), sub(fillDeadlineBuffer, 1))) // _fillDeadline
            mstore(add(ptr, 0x144), 0) // _exclusivityDeadline

            // Handle message
            switch gt(messageLength, 0)
            case 1 {
                mstore(add(ptr, 0x164), add(ptr, 0x184))
                mstore(add(ptr, 0x184), messageLength)

                calldatacopy(add(ptr, 0x1a4), add(currentOffset, 102), messageLength)

                let callSize := add(0x1a4, messageLength)

                // Make the call
                pop(call(gas(), SPOKE_POOL, requiredValue, ptr, callSize, 0x00, 0x00))

                mstore(0x40, add(0x20, add(ptr, callSize))) // one word after the message
            }
            default {
                // No message
                mstore(add(ptr, 0x164), add(ptr, 0x184))
                mstore(add(ptr, 0x184), 0)

                // Make the call
                pop(call(gas(), SPOKE_POOL, requiredValue, ptr, 0x1a4, 0x00, 0x00))

                mstore(0x40, add(0x20, 0x1a4)) // one word after the message
            }
        }

        return currentOffset + 102 + messageLength;
    }
}
