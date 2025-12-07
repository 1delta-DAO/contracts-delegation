// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockSpokePool {
    constructor(
        bytes32 _depositor,
        bytes32 _recipient,
        bytes32 _inputToken,
        bytes32 _outputToken,
        uint256 _inputAmount,
        uint256 _destinationChainId,
        uint32 _fillDeadline,
        bytes memory _message
    ) {
        depositor = _depositor;
        recipient = _recipient;
        inputToken = _inputToken;
        outputToken = _outputToken;
        inputAmount = _inputAmount;
        destinationChainId = _destinationChainId;
        fillDeadline = _fillDeadline;
        message = keccak256(_message);
    }

    bytes32 public depositor;
    bytes32 public recipient;
    bytes32 public inputToken;
    bytes32 public outputToken;
    uint256 public inputAmount;
    uint256 public destinationChainId;
    uint32 public fillDeadline;
    bytes32 public message;

    function deposit(
        bytes32 _depositor,
        bytes32 _recipient,
        bytes32 _inputToken,
        bytes32 _outputToken,
        uint256 _inputAmount,
        uint256 _outputAmount,
        uint256 _destinationChainId,
        bytes32 _exclusiveRelayer,
        uint32 _quoteTimestamp,
        uint32 _fillDeadline,
        uint32 _exclusivityDeadline,
        bytes memory _message
    )
        external
        payable
        returns (bytes memory)
    {
        require(_fillDeadline == fillDeadline, "fill deadline mismatch");

        require(_depositor == depositor, "depositor mismatch");
        require(_recipient == recipient, "recipient mismatch");
        require(_inputToken == inputToken, "inputToken mismatch");
        require(_outputToken == outputToken, "outputToken mismatch");
        require(_inputAmount == inputAmount, "inputAmount mismatch");
        require(_destinationChainId == destinationChainId, "destinationChainId mismatch");
        require(message == keccak256(_message), "message mismatch");
        return new bytes(0);
    }
}
