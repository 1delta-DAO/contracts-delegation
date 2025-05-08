// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct BridgeParams {
    uint256 assetId;
    address stargatePool;
    uint256 dstEid;
    address receiver;
    uint256 amount;
    uint256 slippage;
    uint256 fee;
    bool isBusMode;
    bytes composeMsg;
    bytes extraOptions;
}

interface IStargate {
    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    struct OFTReceipt {
        uint256 amountSentLD; // Amount sent in local decimals
        uint256 amountReceivedLD; // Amount to be received in local decimals
    }

    struct MessagingFee {
        uint256 nativeFee; // Fee in native token
        uint256 lzTokenFee; // Fee in LZ token
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    struct OFTLimit {
        uint256 minAmountLD; // Minimum amount for transfer
        uint256 maxAmountLD; // Maximum amount for transfer
    }

    struct OFTFeeDetail {
        int256 amount; // Fee amount (negative for fee, positive for reward)
        string description; // Description of the fee
    }

    struct Ticket {
        uint72 ticketId; // ID for bus ticket
        bytes passengerBytes; // Passenger data
    }

    function token() external view returns (address);

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt, Ticket memory ticket);

    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory, OFTReceipt memory);

    function quoteSend(SendParam calldata _sendParam, bool _payInLzToken) external view returns (MessagingFee memory);

    function quoteOFT(SendParam calldata _sendParam)
        external
        view
        returns (OFTLimit memory, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory);
}

interface ITokenMessaging {
    function stargateImpls(uint16 assetId) external view returns (address);
}
