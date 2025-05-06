// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct AcrossParams {
    address sendingAssetId;
    address receivingAssetId;
    uint256 amount;
    uint256 outputAmount;
    uint32 destinationChainId;
    address receiver;
    address exclusiveRelayer;
    uint32 quoteTimestamp;
    uint32 fillDeadline;
    uint32 exclusivityDeadline;
    bytes message;
}

interface IAcrossSpokePool {
    function depositV3(
        address depositor,
        address recipient,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destinationChainId,
        address exclusiveRelayer,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityDeadline,
        bytes memory message
    )
        external
        payable;

    function fillDeadlineBuffer() external returns (uint32);
}
