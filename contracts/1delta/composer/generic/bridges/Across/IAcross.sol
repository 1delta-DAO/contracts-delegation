// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAcrossSpokePool {
    function deposit(
        bytes32 depositor,
        bytes32 recipient,
        bytes32 inputToken,
        bytes32 outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destinationChainId,
        bytes32 exclusiveRelayer,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityDeadline,
        bytes memory message
    )
        external
        payable;

    function fillDeadlineBuffer() external view returns (uint32);
}
