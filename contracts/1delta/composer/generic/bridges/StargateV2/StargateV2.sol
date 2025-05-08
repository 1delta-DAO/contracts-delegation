// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
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
     * | 0      | 20             | tokenAddress                 |
     * | 20     | 2              | assetId                      |
     * | 22     | 20             | stargate pool                |
     * | 42     | 4              | dstEid                       |
     * | 46     | 32             | receiver                     |
     * | 78     | 20             | refundReceiver               |
     * | 98     | 16             | amount                       |
     * | 114    | 4              | slippage                     |
     * | 118    | 16             | fee                          |
     * | 134    | 1              | isBusMode                    |
     * | 135    | 2              | composeMsg.length: cl        |
     * | 137    | 2              | extraOptions.length: el      |
     * | 139    | cl             | composeMsg: cm               |
     * | 139+cl | el             | extraOptions: eo             |
     */
    function _bridgeStargateV2(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        BridgeParams memory params;
        uint16 composeMsgLength;
        uint16 extraOptionsLength;
        address asset;
        assembly {
            asset := shr(96, calldataload(currentOffset))
            // Load assetId (2 bytes)
            mstore(params, and(shr(240, calldataload(add(currentOffset, 20))), UINT16_MASK))

            // Load stargate pool (20 bytes)
            mstore(add(params, 32), shr(96, calldataload(add(currentOffset, 22))))

            // Load dstEid (4 bytes)
            mstore(add(params, 64), and(shr(224, calldataload(add(currentOffset, 42))), UINT32_MASK))

            // Load receiver (32 bytes)
            mstore(add(params, 96), calldataload(add(currentOffset, 46)))

            // Load refundReceiver (20 bytes)
            mstore(add(params, 256), shr(96, calldataload(add(currentOffset, 78))))

            // Load amount (16 bytes)
            mstore(add(params, 128), shr(128, calldataload(add(currentOffset, 98))))

            // Load slippage (4 bytes)
            mstore(add(params, 160), and(shr(224, calldataload(add(currentOffset, 114))), UINT32_MASK))

            // Load fee (16 bytes)
            mstore(add(params, 192), shr(128, calldataload(add(currentOffset, 118))))

            // Load isBusMode (1 byte)
            mstore(add(params, 224), and(shr(248, calldataload(add(currentOffset, 134))), UINT8_MASK))

            // Load lengths
            composeMsgLength := and(shr(240, calldataload(add(currentOffset, 135))), UINT16_MASK)
            extraOptionsLength := and(shr(240, calldataload(add(currentOffset, 137))), UINT16_MASK)
        }

        if (composeMsgLength > 0) {
            params.composeMsg = new bytes(composeMsgLength);
            assembly {
                calldatacopy(
                    add(mload(add(params, 288)), 0x20), // Pointer to composeMsg data area
                    add(currentOffset, 139),
                    composeMsgLength
                )
            }
        }

        if (extraOptionsLength > 0) {
            params.extraOptions = new bytes(extraOptionsLength);
            assembly {
                calldatacopy(
                    add(mload(add(params, 320)), 0x20), // Pointer to extraOptions data area
                    add(add(currentOffset, 139), composeMsgLength),
                    extraOptionsLength
                )
            }
        }

        _bridgeTokens(callerAddress, asset, params);

        // Calculate new offset
        return currentOffset + 139 + composeMsgLength + extraOptionsLength;
    }

    function _bridgeTokens(address _caller, address tokenAddr, BridgeParams memory _params) internal {
        // Check if the token is native or ERC20
        bool isNative = tokenAddr == address(0);

        // get the native balance at the beginning
        uint256 selfNativeBalance;
        assembly {
            selfNativeBalance := selfbalance()
        }

        // initialize the total callvalue to send
        uint256 requiredValue;

        console.log("_params.amount:", _params.amount, _caller);
        // if amount is 0, then use the balance of the contract
        if (_params.amount == 0) {
            if (isNative) {
                // amount is the balance minus the fee
                _params.amount = selfNativeBalance - _params.fee;
                // and value to send is everything
                requiredValue = selfNativeBalance;
            } else {
                // use token balance
                _params.amount = IERC20(tokenAddr).balanceOf(address(this));
                // value to send is just the fee
                requiredValue = _params.fee;
                // check if fee is enough
                if (requiredValue > selfNativeBalance) revert InsufficientValue();
            }
        } else {
            if (isNative) {
                // value to send is amount desired plus fee
                requiredValue = _params.amount + _params.fee;
            } else {
                // erc20 case: value is just the fee
                requiredValue = _params.fee;
            }
            // check if we have enough to pay the fee
            if (requiredValue > selfNativeBalance) revert InsufficientValue();
        }

        console.log("_params.amount:", _params.amount);

        console.log("requiredValue:", requiredValue);

        // Create the sendParam structure
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: uint32(_params.dstEid),
            to: _params.receiver,
            amountLD: _params.amount,
            // use standard slippage adjustment for slippage
            minAmountLD: (_params.amount * (FEE_DENOMINATOR - _params.slippage)) / FEE_DENOMINATOR,
            extraOptions: _params.extraOptions,
            composeMsg: _params.composeMsg,
            oftCmd: _params.isBusMode ? new bytes(1) : new bytes(0) // Bus or taxi mode
        });

        // call stargate
        (bool success, bytes memory data) = _params.stargatePool.call{value: requiredValue}(
            abi.encodeWithSelector(
                IStargate.sendToken.selector,
                sendParam,
                IStargate.MessagingFee({nativeFee: _params.fee, lzTokenFee: 0}),
                // We need this as a custom parameter
                // that is because the caller can be another composer
                payable(_params.refundAddress)
            )
        );

        // forward the error if any
        if (!success) {
            assembly {
                revert(add(data, 32), mload(data))
            }
        }
    }
}
