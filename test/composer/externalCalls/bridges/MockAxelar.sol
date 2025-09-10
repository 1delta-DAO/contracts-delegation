// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";

contract MockAxelar {
    string public expectedDestinationChain;
    string public expectedDestinationAddress;
    string public expectedSymbol;
    uint256 public expectedAmount;

    // callContractWithToken expecteds
    string public expectedCCWDestinationChain;
    string public expectedCCWContractAddress;
    bytes public expectedCCWPayload;
    string public expectedCCWSymbol;
    uint256 public expectedCCWAmount;

    function setExpectedSendToken(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata symbol,
        uint256 amount
    )
        external
    {
        expectedDestinationChain = destinationChain;
        expectedDestinationAddress = destinationAddress;
        expectedSymbol = symbol;
        expectedAmount = amount;
    }

    function sendToken(string calldata destinationChain, string calldata destinationAddress, string calldata symbol, uint256 amount) external {
        require(keccak256(bytes(destinationChain)) == keccak256(bytes(expectedDestinationChain)), "destinationChain mismatch");
        require(keccak256(bytes(destinationAddress)) == keccak256(bytes(expectedDestinationAddress)), "destinationAddress mismatch");
        require(keccak256(bytes(symbol)) == keccak256(bytes(expectedSymbol)), "symbol mismatch");
        require(amount == expectedAmount, "amount mismatch");
    }

    function callContractWithToken(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount
    )
        external
    {
        require(keccak256(bytes(destinationChain)) == keccak256(bytes(expectedCCWDestinationChain)), "destinationChain mismatch");
        require(keccak256(bytes(contractAddress)) == keccak256(bytes(expectedCCWContractAddress)), "contractAddress mismatch");
        require(keccak256(payload) == keccak256(expectedCCWPayload), "payload mismatch");
        require(keccak256(bytes(symbol)) == keccak256(bytes(expectedCCWSymbol)), "symbol mismatch");
        require(amount == expectedCCWAmount, "amount mismatch");
    }

    function setExpectedCallContractWithToken(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount
    )
        external
    {
        expectedCCWDestinationChain = destinationChain;
        expectedCCWContractAddress = contractAddress;
        expectedCCWPayload = payload;
        expectedCCWSymbol = symbol;
        expectedCCWAmount = amount;
    }
}
