// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IStargate.sol";

contract StargateV2 is BaseUtils {
    /**
     * @notice Handles Stargate V2 bridging operations
     * @dev Decodes calldata and forwards the call to the appropriate Stargate adapter function
     * @param currentOffset Current position in the calldata
     * @param callerAddress Original caller's address (for possible access control)
     * @return Updated calldata offset after processing
     *
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 2              | assetId                      |
     * | 2      | 20             | stargate pool                |
     * | 22     | 4              | dstEid                       |
     * | 26     | 20             | receiver                     |
     * | 46     | 16             | amount                       |
     * | 62     | 4              | slippage                     |
     * | 66     | 16             | fee                          |
     * | 82     | 1              | isBusMode                    |
     * | 83     | 2              | composeMsg.length: cl        |
     * | 85     | 2              | extraOptions.length: el      |
     * | 87     | cl             | composeMsg: cm               |
     * | 87+cl  | el             | extraOptions: eo             |
     */
    function _bridgeStargateV2(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        BridgeParams memory params;
        uint16 composeMsgLength;
        uint16 extraOptionsLength;

        assembly {
            // Load assetId (2 bytes)
            mstore(add(params, 0), and(shr(240, calldataload(currentOffset)), UINT16_MASK))

            // Load stargate pool (20 bytes)
            mstore(add(params, 32), shr(96, calldataload(add(currentOffset, 2))))

            // Load dstEid (4 bytes)
            mstore(add(params, 64), and(shr(224, calldataload(add(currentOffset, 22))), UINT32_MASK))

            // Load receiver
            mstore(add(params, 96), shr(96, calldataload(add(currentOffset, 26))))

            // Load amount (16 bytes)
            mstore(add(params, 128), and(shr(128, calldataload(add(currentOffset, 46))), UINT128_MASK))

            // Load slippage (4 bytes)
            mstore(add(params, 160), and(shr(224, calldataload(add(currentOffset, 62))), UINT32_MASK))

            // Load fee (16 bytes)
            mstore(add(params, 192), and(shr(128, calldataload(add(currentOffset, 66))), UINT128_MASK))

            // Load isBusMode (1 byte)
            mstore(add(params, 224), and(shr(248, calldataload(add(currentOffset, 82))), 0xFF))

            // Load lengths
            composeMsgLength := and(shr(240, calldataload(add(currentOffset, 83))), UINT16_MASK)
            extraOptionsLength := and(shr(240, calldataload(add(currentOffset, 85))), UINT16_MASK)
        }

        if (composeMsgLength > 0) {
            params.composeMsg = new bytes(composeMsgLength);
            assembly {
                calldatacopy(
                    add(mload(add(params, 256)), 0x20), // Pointer to composeMsg data area
                    add(currentOffset, 87),
                    composeMsgLength
                )
            }
        }

        if (extraOptionsLength > 0) {
            params.extraOptions = new bytes(extraOptionsLength);
            assembly {
                calldatacopy(
                    add(mload(add(params, 288)), 0x20), // Pointer to extraOptions data area
                    add(add(currentOffset, 87), composeMsgLength),
                    extraOptionsLength
                )
            }
        }

        _bridgeTokens(callerAddress, params);

        // Calculate new offset
        return currentOffset + 87 + composeMsgLength + extraOptionsLength;
    }

    function _bridgeTokens(address _caller, BridgeParams memory _params) internal {
        IStargate stargate = IStargate(_params.stargatePool);

        // Check if the token is native or ERC20
        address tokenAddr = stargate.token();
        bool isNative = tokenAddr == address(0);

        uint256 requiredValue = address(this).balance;

        // if amount is 0, then use the balance of the contract
        if (_params.amount == 0) {
            if (isNative) {
                _params.amount = uint128(address(this).balance - _params.fee);
            } else {
                _params.amount = uint128(IERC20(tokenAddr).balanceOf(address(this)));
                // check if fee is enough
                if (_params.fee != address(this).balance) revert InsufficientValue();
            }
        } else {
            if (isNative) {
                // check if enough founds are attached
                if (_params.amount + _params.fee != address(this).balance) {
                    revert InsufficientValue();
                }
            } else {
                if (_params.fee != address(this).balance) revert InsufficientValue();
            }
        }

        uint256 minAmount = (_params.amount * (1e9 - _params.slippage)) / 1e9;

        // Create the sendParam structure
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: _params.dstEid,
            to: bytes32(uint256(uint160(_params.receiver))),
            amountLD: _params.amount,
            minAmountLD: minAmount,
            extraOptions: _params.extraOptions,
            composeMsg: _params.composeMsg,
            oftCmd: _params.isBusMode ? new bytes(1) : new bytes(0) // Bus or taxi mode
        });

        (bool success, bytes memory data) = address(stargate).call{value: requiredValue}(
            abi.encodeWithSelector(
                IStargate.sendToken.selector,
                sendParam,
                IStargate.MessagingFee({nativeFee: _params.fee, lzTokenFee: 0}),
                payable(_caller) // Refund to caller
            )
        );

        if (!success) revert BridgeFailed();

        (, IStargate.OFTReceipt memory oftReceipt,) = abi.decode(data, (IStargate.MessagingReceipt, IStargate.OFTReceipt, IStargate.Ticket));
        if (oftReceipt.amountReceivedLD < minAmount) {
            revert SlippageTooHigh(minAmount, oftReceipt.amountReceivedLD);
        }
    }
}
