// SPDX-License-Identifier: MIT
// solhint-disable max-line-length
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";

contract MockSquidRouter {
    string public expectedSquidBridgedTokenSymbol;
    uint256 public expectedSquidAmount;
    uint256 public expectedSquidNativeAmount;
    string public expectedSquidDestinationChain;
    string public expectedSquidDestinationAddress;
    bytes public expectedSquidPayload;
    address public expectedSquidGasRefundRecipient;
    bool public expectedSquidEnableExpress;

    function setExpectedSquidCall(
        string calldata bridgedTokenSymbol,
        uint256 amount,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address gasRefundRecipient,
        bool enableExpress,
        uint256 nativeAmount
    )
        external
    {
        expectedSquidBridgedTokenSymbol = bridgedTokenSymbol;
        expectedSquidAmount = amount;
        expectedSquidNativeAmount = nativeAmount;
        expectedSquidDestinationChain = destinationChain;
        expectedSquidDestinationAddress = destinationAddress;
        expectedSquidPayload = payload;
        expectedSquidGasRefundRecipient = gasRefundRecipient;
        expectedSquidEnableExpress = enableExpress;
    }

    function bridgeCall(
        string calldata bridgedTokenSymbol,
        uint256 amount,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address gasRefundRecipient,
        bool enableExpress
    )
        external
        payable
    {
        require(
            keccak256(bytes(bridgedTokenSymbol)) == keccak256(bytes(expectedSquidBridgedTokenSymbol)),
            "bridgedTokenSymbol mismatch"
        );
        require(amount == expectedSquidAmount, "amount mismatch");
        require(
            keccak256(bytes(destinationChain)) == keccak256(bytes(expectedSquidDestinationChain)), "destinationChain mismatch"
        );
        require(
            keccak256(bytes(destinationAddress)) == keccak256(bytes(expectedSquidDestinationAddress)),
            "destinationAddress mismatch"
        );
        require(keccak256(payload) == keccak256(expectedSquidPayload), "payload mismatch");
        require(gasRefundRecipient == expectedSquidGasRefundRecipient, "gasRefundRecipient mismatch");
        require(enableExpress == expectedSquidEnableExpress, "enableExpress mismatch");
        require(msg.value == expectedSquidNativeAmount, "nativeAmount mismatch");
    }
}
