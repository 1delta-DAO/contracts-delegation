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
    MockContract private mockContract;

    address private constant XCDOT = 0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080;
    address private constant STELLA_STDOT = 0xbc7E02c4178a7dF7d3E564323a5c359dc96C4db4;
    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    bytes private constant DEPOSIT_CALLDATA = abi.encodeWithSelector(DEPOSIT_SELECTOR, 0);

    bytes4 private constant DEPOSIT_SELECTOR = 0xb6b55f25;
    bytes4 private constant TRANSFER_FROM_SELECTOR = 0x23b872dd;

    function setUp() public {
        _init(Chains.MOONBEAM, 13320695, true);

        callForwarder = new CallForwarder();
        mockContract = new MockContract();
        composer = ComposerPlugin.getComposer(Chains.MOONBEAM);

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(mockContract), "MockContract");
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
}

contract MockContract {
    bool public shouldFail;
    bool public called;
    bool public catchCalled;

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }

    function testCall() external {
        called = true;

        if (shouldFail) {
            revert ShouldRevert();
        }
    }

    function catchBlock() external {
        catchCalled = true;
    }

    function reset() external {
        called = false;
        catchCalled = false;
    }
}

