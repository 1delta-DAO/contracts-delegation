// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IStargate.sol";

contract StargateV2 is BaseUtils {
    // https://stargateprotocol.gitbook.io/stargate/v2-developer-docs/technical-reference/mainnet-contracts
    address internal constant TOKENMESSAGING = 0x19cFCE47eD54a88614648DC3f19A5980097007dD; // Arbitrum
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
     * | 2      | 4              | dstEid                       |
     * | 6      | 20             | receiver                     |
     * | 26     | 16             | amount                       |
     * | 42     | 4              | slippage                     |
     * | 46     | 16             | fee                          |
     * | 62     | 1              | isBusMode                    |
     * | 63     | 2              | composeMsg.length: cl        |
     * | 65     | 2              | extraOptions.length: el      |
     * | 67     | cl             | composeMsg: cm               |
     * | 67+cl  | el             | extraOptions: eo             |
     */

    function _bridgeStargateV2(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        BridgeParams memory params;
        uint16 composeMsgLength;
        uint16 extraOptionsLength;

        assembly {
            // Load assetId (2 bytes)
            mstore(add(params, 0), and(shr(240, calldataload(currentOffset)), UINT16_MASK))

            // Load dstEid (4 bytes)
            mstore(add(params, 32), and(shr(224, calldataload(add(currentOffset, 2))), UINT32_MASK))

            // Load receiver
            mstore(add(params, 64), shr(96, calldataload(add(currentOffset, 6))))

            // Load amount (16 bytes)
            mstore(add(params, 96), and(shr(128, calldataload(add(currentOffset, 26))), UINT128_MASK))

            // Load slippage (4 bytes)
            mstore(add(params, 128), and(shr(224, calldataload(add(currentOffset, 42))), UINT32_MASK))

            // Load fee (16 bytes)
            mstore(add(params, 160), and(shr(128, calldataload(add(currentOffset, 46))), UINT128_MASK))

            // Load isBusMode (1 byte)
            mstore(add(params, 192), and(shr(248, calldataload(add(currentOffset, 62))), 0xFF))

            // Load lengths
            composeMsgLength := and(shr(240, calldataload(add(currentOffset, 63))), UINT16_MASK)
            extraOptionsLength := and(shr(240, calldataload(add(currentOffset, 65))), UINT16_MASK)
        }

        if (composeMsgLength > 0) {
            params.composeMsg = new bytes(composeMsgLength);
            assembly {
                calldatacopy(
                    add(mload(add(params, 224)), 32), // Pointer to composeMsg data area
                    add(currentOffset, 67),
                    composeMsgLength
                )
            }
        }

        if (extraOptionsLength > 0) {
            params.extraOptions = new bytes(extraOptionsLength);
            assembly {
                calldatacopy(
                    add(mload(add(params, 256)), 32), // Pointer to extraOptions data area
                    add(add(currentOffset, 67), composeMsgLength),
                    extraOptionsLength
                )
            }
        }

        _bridgeTokens(callerAddress, params);

        // Calculate new offset
        return currentOffset + 67 + composeMsgLength + extraOptionsLength;
    }

    function _bridgeTokens(address _caller, BridgeParams memory _params) internal {
        // Get the Stargate implementation for this asset
        address stargateAddr = ITokenMessaging(TOKENMESSAGING).stargateImpls(_params.assetId);
        if (stargateAddr == address(0)) revert InvalidAssetId(_params.assetId);

        // Get the Stargate contract
        IStargate stargate = IStargate(stargateAddr);

        // Check if the token is native or ERC20
        address tokenAddr = stargate.token();
        bool isNative = tokenAddr == address(0);

        uint256 requiredValue;

        // if amount is 0, then use the balance of the contract
        if (_params.amount == 0) {
            if (isNative) {
                _params.amount = uint128(address(this).balance - _params.fee);
                requiredValue = address(this).balance;
            } else {
                _params.amount = uint128(IERC20(tokenAddr).balanceOf(address(this)));
                // check if fee is enough
                if (_params.fee != address(this).balance) revert InsufficientValue();
                requiredValue = address(this).balance;
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
            requiredValue = address(this).balance;
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

        // Handle token allowance
        /// @notice if the token is not native, then there should be an approve command for call forwarder before this bridge call
        /// to make sure that the stargate has enough allowance to get the token

        // Execute the bridge operation

        (bool success, bytes memory data) = address(stargate).call{value: requiredValue}(
            abi.encodeWithSelector(
                IStargate.sendToken.selector,
                sendParam,
                IStargate.MessagingFee({nativeFee: _params.fee, lzTokenFee: 0}),
                payable(_caller) // Refund to caller
            )
        );
        // we'll refund the tokens in another composer call

        // Check slippage
        (, IStargate.OFTReceipt memory oftReceipt,) = abi.decode(data, (IStargate.MessagingReceipt, IStargate.OFTReceipt, IStargate.Ticket));
        if (oftReceipt.amountReceivedLD < minAmount) {
            revert SlippageTooHigh(minAmount, oftReceipt.amountReceivedLD);
        }
    }
}
