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
import {MockStargate} from "./MockStargate.sol";

contract StargateV2Test is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant FEE_DENOMINATOR = 1e9;
    // Contract instances
    CallForwarder private callForwarder;
    IComposerLike private composer;

    // Stargate V2 contracts on Arbitrum
    address public constant TOKENMESSAGING = 0x19cFCE47eD54a88614648DC3f19A5980097007dD; // Arbitrum
    address public STARGATE_USDC; // = 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3; // USDC Stargate
    address public STARGATE_USDC_REAL = 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3; // USDC Stargate
    MockStargate public STARGATE_MOCK; // USDC Stargate

    // Test parameters
    uint32 public constant POLYGON_EID = 30109;
    address public USDC;

    // Test amounts
    uint256 public BRIDGE_AMOUNT = 1000 * 1e6;

    function setUp() public {
        rpcOverrides[Chains.ARBITRUM_ONE] = "https://arbitrum.blockpi.network/v1/rpc/public";
        _init(Chains.ARBITRUM_ONE, 333862337, true);

        callForwarder = new CallForwarder();

        composer = ComposerPlugin.getComposer(Chains.ARBITRUM_ONE);

        USDC = chain.getTokenAddress(Tokens.USDC);

        _fundUserWithToken(USDC, BRIDGE_AMOUNT);

        STARGATE_MOCK = new MockStargate();

        STARGATE_USDC = address(STARGATE_MOCK);

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(composer), "Composer");
        vm.label(STARGATE_USDC, "StargateUSDC");
        vm.label(address(STARGATE_MOCK), "StargateUSDC Mock");
        vm.label(USDC, "USDC");
        vm.label(user, "User");
    }

    function test_stargate_v2_bridge_taxi_native_balance() public {
        uint32 baseId = 30184;
        address nativePool = address(STARGATE_MOCK);
        // 1. quote the fee
        (
            uint256 fee,
            int256 sgFee,
            IStargate.SendParam memory sendParam,
            IStargate.MessagingFee memory param //
        ) = _quote(false, 1);

        uint256 eth_amount = 1 ether;
        // set expected params
        sendParam.dstEid = baseId;
        sendParam.amountLD = eth_amount;
        sendParam.minAmountLD = eth_amount * 90 / 100; // adjsut for 10%
        // set expecteds
        STARGATE_MOCK.setExpectedParams(sendParam, param, user);

        deal(address(composer), fee + eth_amount);

        bytes memory forwarderCalldata = abi.encodePacked(
            CalldataLib.encodeStargateV2BridgeSimpleTaxi(
                address(0),
                nativePool,
                baseId, // dst id
                toReceiver(user), // receiver
                user, // refund receiver
                0, // amount = balance
                true,
                100000000, // slippage 10%
                fee
            ),
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE) // sweep native
        );

        bytes memory composerCalldata = abi.encodePacked(
            CalldataLib.encodeSweep(address(0), address(callForwarder), 0, SweepType.VALIDATE),
            CalldataLib.encodeExternalCall(address(callForwarder), 0, forwarderCalldata)
        );

        vm.startPrank(user);
        // Approve USDC to the CallForwarder
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(composerCalldata);

        vm.stopPrank();
    }

    function test_stargate_v2_bridge_taxi_token_amount() public {
        // 1. quote the fee
        (
            uint256 fee,
            int256 sgFee,
            IStargate.SendParam memory sendParam,
            IStargate.MessagingFee memory param //
        ) = _quote(false, 1);

        uint256 minAmountLD = uint256(int256(BRIDGE_AMOUNT) + sgFee); // sgFee is negative for fee and positive for rewards
        sendParam.minAmountLD = minAmountLD;

        // set expecteds
        STARGATE_MOCK.setExpectedParams(sendParam, param, user);

        uint32 slippage = uint32((BRIDGE_AMOUNT - minAmountLD) * 1e9 / BRIDGE_AMOUNT); // percentage

        deal(address(callForwarder), fee);

        // 2. compose call data

        console.log("lzFee", fee);
        console.log("sgFee", sgFee);
        console.log("BRIDGE_AMOUNT", BRIDGE_AMOUNT);
        console.log("minAmountLD", minAmountLD);
        console.log("slippage", slippage);
        bytes memory totalCalldata = CalldataLib.encodeStargateV2BridgeSimpleTaxi(
            USDC,
            STARGATE_USDC,
            POLYGON_EID,
            toReceiver(user), //
            user,
            // refund receiver
            BRIDGE_AMOUNT,
            false,
            slippage,
            fee
        );
        totalCalldata = abi.encodePacked(
            CalldataLib.encodeApprove(USDC, STARGATE_USDC),
            totalCalldata,
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE), // sweep native
            CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE) // sweep usdc
        );

        totalCalldata = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
            CalldataLib.encodeExternalCall(address(callForwarder), 0, totalCalldata)
        );

        vm.startPrank(user);
        // Approve USDC to the CallForwarder
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(totalCalldata);

        vm.stopPrank();
    }

    function test_stargate_v2_bridge_taxi_token_balance() public {
        // 1. quote the fee
        (
            uint256 fee,
            int256 sgFee,
            IStargate.SendParam memory sendParam,
            IStargate.MessagingFee memory param //
        ) = _quote(false, 1);

        uint256 minAmountLD = uint256(int256(BRIDGE_AMOUNT) + sgFee); // sgFee is negative for fee and positive for rewards
        uint32 slippage = uint32((BRIDGE_AMOUNT - minAmountLD) * 1e9 / BRIDGE_AMOUNT); // percentage

        // set expecteds
        sendParam.minAmountLD = minAmountLD;
        STARGATE_MOCK.setExpectedParams(sendParam, param, user);

        deal(address(callForwarder), fee);

        // 2. compose call data

        console.log("lzFee", fee);
        console.log("sgFee", sgFee);
        console.log("BRIDGE_AMOUNT", BRIDGE_AMOUNT);
        console.log("minAmountLD", minAmountLD);
        console.log("slippage", slippage);
        bytes memory totalCalldata = CalldataLib.encodeStargateV2BridgeSimpleTaxi(
            USDC,
            STARGATE_USDC,
            POLYGON_EID,
            toReceiver(user), // receiver
            user, // refund receiver
            0,
            false,
            slippage,
            fee
        );
        totalCalldata = abi.encodePacked(
            CalldataLib.encodeApprove(USDC, STARGATE_USDC),
            totalCalldata,
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE), // sweep native
            CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE) // sweep usdc
        );

        totalCalldata = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
            CalldataLib.encodeExternalCall(address(callForwarder), 0, totalCalldata)
        );

        vm.startPrank(user);
        // Approve USDC to the CallForwarder
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(totalCalldata);

        vm.stopPrank();
    }

    function test_stargate_v2_bridge_taxi_revert_slippage() public {
        // 1. quote the fee
        uint256 fee;
        int256 sgFee;
        {
            IStargate.SendParam memory sendParam;
            IStargate.MessagingFee memory param;
            (
                fee,
                sgFee,
                sendParam,
                param //
            ) = _quote(false, 1);

            STARGATE_MOCK.setExpectedParams(sendParam, param, user);
        }
        uint256 minAmountLD = uint256(int256(BRIDGE_AMOUNT) + sgFee); // sgFee is negative for fee and positive for rewards
        uint32 slippage = uint32((BRIDGE_AMOUNT - minAmountLD) * 1e9 / BRIDGE_AMOUNT); // percentage

        deal(address(callForwarder), fee);

        // 2. compose call data

        console.log("lzFee", fee);
        console.log("sgFee", sgFee);
        console.log("BRIDGE_AMOUNT", BRIDGE_AMOUNT);
        console.log("minAmountLD", minAmountLD);

        bytes memory totalCalldata;
        {
            totalCalldata = abi.encodePacked(
                CalldataLib.encodeApprove(USDC, STARGATE_USDC),
                CalldataLib.encodeStargateV2BridgeSimpleTaxi(
                    USDC,
                    STARGATE_USDC,
                    POLYGON_EID,
                    toReceiver(user), //
                    user,
                    // refund receiver
                    BRIDGE_AMOUNT,
                    false,
                    slippage,
                    fee
                ),
                CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE), // sweep native
                CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE) // sweep usdc
            );
        }

        totalCalldata = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
            CalldataLib.encodeExternalCall(address(callForwarder), 0, totalCalldata)
        );

        vm.startPrank(user);
        // Approve USDC to the CallForwarder
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        vm.expectRevert();
        composer.deltaCompose(totalCalldata);

        vm.stopPrank();
    }

    function test_stargate_v2_bridge_bus_token_amount() public {
        // 1. quote the fee
        (
            uint256 fee,
            int256 sgFee,
            IStargate.SendParam memory sendParam,
            IStargate.MessagingFee memory param //
        ) = _quote(true, 1);
        uint256 minAmountLD; // sgFee is negative for fee and positive for rewards
        uint32 slippage;
        {
            minAmountLD = uint256(int256(BRIDGE_AMOUNT) + sgFee); // sgFee is negative for fee and positive for rewards
            slippage = uint32((BRIDGE_AMOUNT - minAmountLD) * 1e9 / BRIDGE_AMOUNT); // percentage

            // set expecteds
            sendParam.minAmountLD = minAmountLD;
            sendParam.extraOptions = hex"e7a0fffffff01111111eee";
            sendParam.composeMsg = hex"c0c0c0c0c0c0c0c0c0c0cddd";
            sendParam.oftCmd = hex"0000000000000000000000000000000000000000000000000000000000000000";

            STARGATE_MOCK.setExpectedParams(sendParam, param, user);

            deal(address(callForwarder), fee);

            // 2. compose call data

            console.log("lzFee", fee);
            console.log("sgFee", sgFee);
            console.log("BRIDGE_AMOUNT", BRIDGE_AMOUNT);
            console.log("minAmountLD", minAmountLD);
        }

        {
            // log params
            console.log("sendParam");
            console.logBytes(abi.encodeWithSelector(MockStargate.sendToken.selector, sendParam, param, user));
            console.log("///////////////////");
        }

        bytes memory totalCalldata = CalldataLib.encodeStargateV2Bridge(
            USDC,
            STARGATE_USDC,
            POLYGON_EID,
            toReceiver(user), //
            user,
            // refund receiver
            BRIDGE_AMOUNT,
            slippage,
            fee,
            true,
            false,
            hex"c0c0c0c0c0c0c0c0c0c0cddd",
            hex"e7a0fffffff01111111eee"
        );
        totalCalldata = abi.encodePacked(
            CalldataLib.encodeApprove(USDC, STARGATE_USDC),
            totalCalldata,
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE), // sweep native
            CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE) // sweep usdc
        );

        totalCalldata = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
            CalldataLib.encodeExternalCall(address(callForwarder), 0, totalCalldata)
        );

        vm.startPrank(user);
        // Approve USDC to the CallForwarder
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(totalCalldata);

        vm.stopPrank();
    }

    function test_stargate_v2_bridge_bus_token_balance() public {
        // 1. quote the fee
        (
            uint256 fee,
            int256 sgFee,
            IStargate.SendParam memory sendParam,
            IStargate.MessagingFee memory param //
        ) = _quote(true, 1);

        uint256 minAmountLD = uint256(int256(BRIDGE_AMOUNT) + sgFee); // sgFee is negative for fee and positive for rewards
        uint32 slippage = uint32((BRIDGE_AMOUNT - minAmountLD) * 1e9 / BRIDGE_AMOUNT); // percentage

        // set expecteds
        sendParam.minAmountLD = minAmountLD;
        STARGATE_MOCK.setExpectedParams(sendParam, param, user);

        deal(address(callForwarder), fee);

        // 2. compose call data

        console.log("lzFee", fee);
        console.log("sgFee", sgFee);
        console.log("BRIDGE_AMOUNT", BRIDGE_AMOUNT);
        console.log("minAmountLD", minAmountLD);
        bytes memory totalCalldata = CalldataLib.encodeStargateV2BridgeSimpleBus(
            USDC,
            STARGATE_USDC,
            POLYGON_EID,
            toReceiver(user), //
            user,
            // refund receiver
            0,
            false,
            slippage,
            fee
        );
        totalCalldata = abi.encodePacked(
            CalldataLib.encodeApprove(USDC, STARGATE_USDC),
            totalCalldata,
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE), // sweep native
            CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE) // sweep usdc
        );

        totalCalldata = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDC, address(callForwarder), BRIDGE_AMOUNT),
            CalldataLib.encodeExternalCall(address(callForwarder), 0, totalCalldata)
        );

        vm.startPrank(user);
        // Approve USDC to the CallForwarder
        IERC20(USDC).approve(address(composer), BRIDGE_AMOUNT);

        composer.deltaCompose(totalCalldata);

        vm.stopPrank();
    }

    // helper functions

    function _quote(
        bool busMode,
        uint256 slippage
    )
        private
        returns (
            uint256,
            int256, //
            IStargate.SendParam memory sendParam,
            IStargate.MessagingFee memory param
        )
    {
        sendParam = IStargate.SendParam({
            dstEid: POLYGON_EID,
            to: bytes32(uint256(uint160(user))),
            amountLD: BRIDGE_AMOUNT,
            minAmountLD: (BRIDGE_AMOUNT * (FEE_DENOMINATOR - slippage)) / FEE_DENOMINATOR,
            extraOptions: new bytes(0),
            composeMsg: new bytes(0),
            oftCmd: busMode ? new bytes(1) : new bytes(0) // Bus or taxi mode
        });
        (
            IStargate.OFTLimit memory limit, //
            IStargate.OFTFeeDetail[] memory oftFeeDetails,
            IStargate.OFTReceipt memory receipt
        ) = IStargate(STARGATE_USDC_REAL).quoteOFT(sendParam);

        uint256 msgFee = IStargate(STARGATE_USDC_REAL).quoteSend(sendParam, false).nativeFee;

        param = IStargate.MessagingFee(msgFee, 0);

        return (msgFee, oftFeeDetails[0].amount, sendParam, param);
    }

    function toReceiver(address r) internal pure returns (bytes32 receiver) {
        assembly {
            receiver := r
        }
    }
}
