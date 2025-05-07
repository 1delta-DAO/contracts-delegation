// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CallForwarder} from "contracts/1delta/composer/generic/CallForwarder.sol";
import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {IStargate} from "contracts/1delta/composer/generic/bridges/StargateV2/IStargate.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

contract StargateV2Test is BaseTest {
    using CalldataLib for bytes;

    // Contract instances
    CallForwarder private callForwarder;
    IComposerLike private composer;

    // Stargate V2 contracts on Arbitrum
    address public constant TOKENMESSAGING = 0x19cFCE47eD54a88614648DC3f19A5980097007dD; // Arbitrum
    address public constant STARGATE_USDC = 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3; // USDC Stargate

    // Test parameters
    uint16 public constant USDC_ASSET_ID = 1;
    uint32 public constant POLYGON_EID = 30109;
    address public USDC;

    // Test amounts
    uint256 public BRIDGE_AMOUNT = 1000 * 1e6;

    function setUp() public {
        _init(Chains.ARBITRUM_ONE, 333862337, true);

        callForwarder = new CallForwarder();

        composer = ComposerPlugin.getComposer(Chains.ARBITRUM_ONE);

        USDC = chain.getTokenAddress(Tokens.USDC);

        _fundUserWithToken(USDC, BRIDGE_AMOUNT);

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(composer), "Composer");
        vm.label(STARGATE_USDC, "StargateUSDC");
        vm.label(USDC, "USDC");
        vm.label(user, "User");
    }

    function test_stargate_v2_bridge_taxi() public {
        // 1. quote the fee
        (uint256 fee, int256 sgFee) = _quote(false);

        uint256 minAmountLD = uint256(int256(BRIDGE_AMOUNT) + sgFee); // sgFee is negative for fee and positive for rewards

        deal(address(callForwarder), fee);

        // 2. compose call data

        console.log("lzFee", fee);
        console.log("sgFee", sgFee);
        console.log("BRIDGE_AMOUNT", BRIDGE_AMOUNT);
        console.log("minAmountLD", minAmountLD);

        bytes memory forwarderCalldata = abi.encodePacked(
            CalldataLib.encodeApprove(USDC, STARGATE_USDC),
            CalldataLib.encodeStargateV2BridgeTaxi(USDC_ASSET_ID, POLYGON_EID, user, BRIDGE_AMOUNT, minAmountLD, fee),
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE) // sweep the remaining balance, if any
        );

        bytes memory composerCalldata = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
            CalldataLib.encodeExternalCall(address(callForwarder), 0, forwarderCalldata)
        );

        vm.startPrank(user);
        // Approve USDC to the CallForwarder
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(composerCalldata);

        vm.stopPrank();
    }

    function _quote(bool busMode) private returns (uint256, int256) {
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: POLYGON_EID,
            to: bytes32(uint256(uint160(user))),
            amountLD: BRIDGE_AMOUNT,
            minAmountLD: 0,
            extraOptions: new bytes(0),
            composeMsg: new bytes(0),
            oftCmd: busMode ? new bytes(1) : new bytes(0) // Bus or taxi mode
        });
        (IStargate.OFTLimit memory limit, IStargate.OFTFeeDetail[] memory oftFeeDetails, IStargate.OFTReceipt memory receipt) =
            IStargate(STARGATE_USDC).quoteOFT(sendParam);

        uint256 msgFee = IStargate(STARGATE_USDC).quoteSend(sendParam, false).nativeFee;

        return (msgFee, oftFeeDetails[0].amount);
    }
}
