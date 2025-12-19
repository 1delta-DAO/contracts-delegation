// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import "contracts/1delta/composer/generic/bridges/StargateV2/IStargate.sol";

contract MockStargate is IStargate {
    SendParam public expectedSendParam;
    MessagingFee public expectedFee;
    address public expectedRefundAddress;

    bool public shouldFail;

    function setExpectedParams(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress) external {
        expectedSendParam = _sendParam;
        expectedFee = _fee;
        expectedRefundAddress = _refundAddress;
    }

    function setShouldFail(bool _fail) external {
        shouldFail = _fail;
    }

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        override
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt, Ticket memory ticket)
    {
        require(!shouldFail, "Mock failure triggered");

        console.log("--------- received Calldata -------");
        console.logBytes(abi.encodeWithSelector(MockStargate.sendToken.selector, _sendParam, _fee, _refundAddress));
        console.log("------------- expected -----------");
        console.log("dstEid:", expectedSendParam.dstEid);
        console.logBytes32(expectedSendParam.to);
        console.log("amountLD:", expectedSendParam.amountLD);
        console.log("minAmountLD:", expectedSendParam.minAmountLD);
        console.logBytes(expectedSendParam.extraOptions);
        console.logBytes(expectedSendParam.composeMsg);
        console.logBytes(expectedSendParam.oftCmd);
        console.log("refundAddress", expectedRefundAddress);

        console.log("------------- gotten -----------");
        console.log("dstEid:", _sendParam.dstEid);
        console.logBytes32(_sendParam.to);
        console.log("amountLD:", _sendParam.amountLD);
        console.log("minAmountLD:", _sendParam.minAmountLD);
        console.logBytes(_sendParam.extraOptions);
        console.logBytes(_sendParam.composeMsg);
        console.logBytes(_sendParam.oftCmd);
        console.log("refundAddress", _refundAddress);

        // Validate parameters match expected
        require(_sendParam.dstEid == expectedSendParam.dstEid, "dstEid mismatch");
        require(_sendParam.to == expectedSendParam.to, "to mismatch");
        require(_sendParam.amountLD == expectedSendParam.amountLD, "amountLD mismatch");
        require(_sendParam.minAmountLD == expectedSendParam.minAmountLD, "minAmountLD mismatch");
        require(keccak256(_sendParam.extraOptions) == keccak256(expectedSendParam.extraOptions), "extraOptions mismatch");
        require(keccak256(_sendParam.composeMsg) == keccak256(expectedSendParam.composeMsg), "composeMsg mismatch");
        if (expectedSendParam.oftCmd.length > 0) {
            require(_sendParam.oftCmd.length > 0, "oftCmd mismatch");
        } else {
            require(_sendParam.oftCmd.length == 0, "oftCmd mismatch");
        }

        require(keccak256(abi.encode(_fee)) == keccak256(abi.encode(expectedFee)), "Fee mismatch");
        require(_refundAddress == expectedRefundAddress, "Refund address mismatch");

        // Return dummy values
        msgReceipt = MessagingReceipt({guid: keccak256("guid"), nonce: 1, fee: _fee});

        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.amountLD - 100 // assume 100 fee
        });

        ticket = Ticket({ticketId: 12345, passengerBytes: abi.encodePacked("passenger")});
    }

    // Dummy implementations for interface completeness
    function token() external view override returns (address) {
        return address(0);
    }

    function send(
        SendParam calldata,
        MessagingFee calldata,
        address
    )
        external
        payable
        override
        returns (MessagingReceipt memory, OFTReceipt memory)
    {
        revert("Not implemented in mock");
    }

    function quoteSend(SendParam calldata, bool) external view override returns (MessagingFee memory) {
        revert("Not implemented in mock");
    }

    function quoteOFT(SendParam calldata)
        external
        view
        override
        returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory)
    {
        revert("Not implemented in mock");
    }
}
