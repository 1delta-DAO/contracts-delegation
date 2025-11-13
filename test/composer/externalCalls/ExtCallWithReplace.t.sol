// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {console} from "forge-std/console.sol";
import {CallForwarder} from "contracts/1delta/composer/generic/CallForwarder.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

error ShouldRevert();

contract ExtTryCatchWithReplace is BaseTest {
    using CalldataLib for bytes;

    CallForwarder private callForwarder;
    IComposerLike private composer;
    // MockContract private mockContract;

    address private constant XCDOT = 0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080;
    address private constant STELLA_STDOT = 0xbc7E02c4178a7dF7d3E564323a5c359dc96C4db4;
    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    bytes private constant DEPOSIT_CALLDATA = abi.encodeWithSelector(DEPOSIT_SELECTOR, 0);

    bytes4 private constant DEPOSIT_SELECTOR = 0xb6b55f25;
    bytes4 private constant TRANSFER_FROM_SELECTOR = 0x23b872dd;

    function setUp() public {
        _init(Chains.MOONBEAM, 13320695, true);

        callForwarder = new CallForwarder();
        //mockContract = new MockContract();
        composer = ComposerPlugin.getComposer(Chains.MOONBEAM);

        vm.label(address(callForwarder), "CallForwarder");
        //vm.label(address(mockContract), "MockContract");
        vm.label(address(composer), "Composer");
        vm.label(address(user), "User");
        vm.label(XCDOT, "xcDOT");
        vm.label(STELLA_STDOT, "Stella Staking");
    }

    function test_tryCallExternalWithReplace_replacesBalance() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), amount);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory catchCalldata = CalldataLib.encodeSweep(XCDOT, user, 0, SweepType.VALIDATE);

        bytes memory tryCallCalldata =
            CalldataLib.encodeTryExternalCallWithReplace(STELLA_STDOT, 0, false, XCDOT, 0, DEPOSIT_CALLDATA, false, catchCalldata);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(
                address(callForwarder),
                uint256(0),
                false,
                abi.encodePacked(approveCalldata, tryCallCalldata, CalldataLib.encodeSweep(STELLA_STDOT, user, 0, SweepType.VALIDATE))
            )
        );

        uint256 bb = IERC20(STELLA_STDOT).balanceOf(user);

        vm.startPrank(user);
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();

        uint256 forwarderBalanceAfter = IERC20(XCDOT).balanceOf(address(callForwarder));
        uint256 ba = IERC20(STELLA_STDOT).balanceOf(user);
        assertGt(ba, bb);
        assertEq(forwarderBalanceAfter, 0);
    }

    function test_tryCallExternalWithReplace_skipReplace_whenTokenIsZero() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), amount);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory depositCalldata = abi.encodeWithSelector(DEPOSIT_SELECTOR, 100);

        bytes memory catchCalldata = CalldataLib.encodeSweep(XCDOT, user, 0, SweepType.VALIDATE);

        bytes memory tryCallCalldata =
            CalldataLib.encodeTryExternalCallWithReplace(STELLA_STDOT, 0, false, address(0), 0, depositCalldata, false, catchCalldata);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(
                address(callForwarder),
                uint256(0),
                false,
                abi.encodePacked(approveCalldata, tryCallCalldata, CalldataLib.encodeSweep(STELLA_STDOT, user, 0, SweepType.VALIDATE))
            )
        );

        uint256 bb = IERC20(STELLA_STDOT).balanceOf(user);

        vm.startPrank(user);
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();

        uint256 forwarderBalanceAfter = IERC20(XCDOT).balanceOf(address(callForwarder));
        uint256 ba = IERC20(STELLA_STDOT).balanceOf(user);
        assertGt(ba, bb);
        assertEq(forwarderBalanceAfter, 900);
    }

    function test_tryCallExternalWithReplace_revertsOnInvalidReplaceOffset() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), amount);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory catchCalldata = CalldataLib.encodeSweep(XCDOT, user, 0, SweepType.VALIDATE);

        bytes memory tryCallCalldata =
            CalldataLib.encodeTryExternalCallWithReplace(STELLA_STDOT, 0, false, XCDOT, 100, DEPOSIT_CALLDATA, false, catchCalldata);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(address(callForwarder), uint256(0), false, abi.encodePacked(approveCalldata, tryCallCalldata))
        );

        vm.startPrank(user);
        vm.expectRevert();
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }

    function test_tryCallExternalWithReplace_revertsOnTransferFromSelector() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), amount);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory transferFromCalldata = abi.encodeWithSelector(TRANSFER_FROM_SELECTOR, address(0), address(0), uint256(0));

        bytes memory catchCalldata = CalldataLib.encodeSweep(XCDOT, user, 0, SweepType.VALIDATE);

        bytes memory tryCallCalldata =
            CalldataLib.encodeTryExternalCallWithReplace(STELLA_STDOT, 0, false, XCDOT, 0, transferFromCalldata, false, catchCalldata);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(address(callForwarder), uint256(0), false, abi.encodePacked(approveCalldata, tryCallCalldata))
        );

        vm.startPrank(user);
        vm.expectRevert();
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }

    function test_tryCallExternalWithReplace_revertsOnPermit2Target() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), amount);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory catchCalldata = CalldataLib.encodeSweep(XCDOT, user, 0, SweepType.VALIDATE);

        bytes memory tryCallCalldata =
            CalldataLib.encodeTryExternalCallWithReplace(PERMIT2, 0, false, XCDOT, 0, DEPOSIT_CALLDATA, false, catchCalldata);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(address(callForwarder), uint256(0), false, abi.encodePacked(approveCalldata, tryCallCalldata))
        );

        vm.startPrank(user);
        vm.expectRevert();
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }

    function test_callExternalWithReplace_replacesBalance() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), amount);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory callCalldata = CalldataLib.encodeExternalCallWithReplace(STELLA_STDOT, 0, false, XCDOT, 0, DEPOSIT_CALLDATA);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(
                address(callForwarder),
                uint256(0),
                false,
                abi.encodePacked(approveCalldata, callCalldata, CalldataLib.encodeSweep(STELLA_STDOT, user, 0, SweepType.VALIDATE))
            )
        );

        uint256 bb = IERC20(STELLA_STDOT).balanceOf(user);

        vm.startPrank(user);
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();

        uint256 forwarderBalanceAfter = IERC20(XCDOT).balanceOf(address(callForwarder));
        uint256 ba = IERC20(STELLA_STDOT).balanceOf(user);
        assertGt(ba, bb);
        assertEq(forwarderBalanceAfter, 0);
    }

    function test_callExternalWithReplace_skipReplace_whenTokenIsZero() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), 500);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory depositCalldata = abi.encodeWithSelector(DEPOSIT_SELECTOR, 500);

        bytes memory callCalldata = CalldataLib.encodeExternalCallWithReplace(STELLA_STDOT, 0, false, address(0), 0, depositCalldata);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(
                address(callForwarder),
                uint256(0),
                false,
                abi.encodePacked(approveCalldata, callCalldata, CalldataLib.encodeSweep(STELLA_STDOT, user, 0, SweepType.VALIDATE))
            )
        );

        uint256 bb = IERC20(STELLA_STDOT).balanceOf(user);

        vm.startPrank(user);
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();

        uint256 forwarderBalanceAfter = IERC20(XCDOT).balanceOf(address(callForwarder));
        uint256 ba = IERC20(STELLA_STDOT).balanceOf(user);
        assertGt(ba, bb);
        assertEq(forwarderBalanceAfter, 0);
    }

    function test_callExternalWithReplace_revertsOnInvalidReplaceOffset() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), amount);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory callCalldata = CalldataLib.encodeExternalCallWithReplace(STELLA_STDOT, 0, false, XCDOT, 100, DEPOSIT_CALLDATA);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(address(callForwarder), uint256(0), false, abi.encodePacked(approveCalldata, callCalldata))
        );

        vm.startPrank(user);
        vm.expectRevert();
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }

    function test_callExternalWithReplace_revertsOnTransferFromSelector() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), amount);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory transferFromCalldata = abi.encodeWithSelector(TRANSFER_FROM_SELECTOR, address(0), address(0), uint256(0));

        bytes memory callCalldata = CalldataLib.encodeExternalCallWithReplace(STELLA_STDOT, 0, false, XCDOT, 0, transferFromCalldata);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(address(callForwarder), uint256(0), false, abi.encodePacked(approveCalldata, callCalldata))
        );

        vm.startPrank(user);
        vm.expectRevert();
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }

    function test_callExternalWithReplace_revertsOnPermit2Target() public {
        uint256 amount = 1000;
        _fundUserWithToken(XCDOT, amount);
        vm.prank(user);
        IERC20(XCDOT).approve(address(composer), type(uint256).max);

        bytes memory transferInCalldata = CalldataLib.encodeTransferIn(XCDOT, address(callForwarder), amount);

        bytes memory approveCalldata = CalldataLib.encodeApprove(XCDOT, STELLA_STDOT);

        bytes memory callCalldata = CalldataLib.encodeExternalCallWithReplace(PERMIT2, 0, false, XCDOT, 0, DEPOSIT_CALLDATA);

        bytes memory composerCalldata = abi.encodePacked(
            transferInCalldata,
            CalldataLib.encodeExternalCall(address(callForwarder), uint256(0), false, abi.encodePacked(approveCalldata, callCalldata))
        );

        vm.startPrank(user);
        vm.expectRevert();
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }
}

