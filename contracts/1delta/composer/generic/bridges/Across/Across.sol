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
     * | 72     | 16             | FeePercentage                |
     * | 88     | 4              | destinationChainId           |
     * | 92     | 20             | receiver                     |
     * | 112    | 2              | message.length: msgLen       |
     * | 114    | msgLen         | message                      |
     */
    function _bridgeAcross(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        // Local variables to store key data
        address sendingAssetId;
        uint256 amount;
        uint256 outputAmount;
        uint16 messageLength;
        uint28 fixedFee;
        uint28 feePercentage;
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
            // load fees
            fixedFee := and(shr(128, calldataload(add(currentOffset, 56))), UINT28_MASK)
            feePercentage := and(shr(128, calldataload(add(currentOffset, 72))), UINT28_MASK)

            // Load message length
            messageLength := and(shr(240, calldataload(add(currentOffset, 112))), UINT16_MASK)
        }

        if (amount == 0) {
            if (isNative) {
                amount = address(this).balance;
                requiredValue = amount;
            } else {
                amount = IERC20(sendingAssetId).balanceOf(address(this));
            }
        } else {
            if (isNative) {
                // For native assets, make sure enough value is sent
                if (amount != address(this).balance) {
                    revert InsufficientValue();
                }
                requiredValue = amount;
            }
            // for erc20 ones we don't do anything we can check the balance though, but lets continue without checking the balance
        }
        // set the output amount
        outputAmount = (amount * (1 - feePercentage)) - fixedFee;

        // Calculate new offset
        return currentOffset + 114 + messageLength;
    }
}
