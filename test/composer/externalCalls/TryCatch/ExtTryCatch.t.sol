// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {console} from "forge-std/console.sol";
import {CallForwarder} from "contracts/1delta/composer/generic/CallForwarder.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

error ShouldRevert();

contract ExtTryCatch is BaseTest {
    using CalldataLib for bytes;

    // Contract instances
    CallForwarder private callForwarder;
    IComposerLike private composer;
    MockContract private mockContract;

    function setUp() public {
        // unit testing, no forking is required
        _init(Chains.ARBITRUM_ONE, 0, false);

        callForwarder = new CallForwarder();
        mockContract = new MockContract();
        composer = ComposerPlugin.getComposer(Chains.ARBITRUM_ONE);

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(mockContract), "MockContract");
        vm.label(address(composer), "Composer");
        vm.label(address(user), "User");
    }

    function test_externalTryCall_reverts_if_not_successful() public {
        // Configure mock to fail
        mockContract.setShouldFail(true);
        mockContract.reset();

        // catch calldata, should not be called in this test
        bytes memory composerCalldata =
            CalldataLib.encodeExternalCall(address(mockContract), uint256(0), false, abi.encodeWithSelector(MockContract.catchBlock.selector));

        // forwarder calldata
        composerCalldata = CalldataLib.encodeTryExternalCall(
            address(mockContract), uint256(0), false, true, abi.encodeWithSelector(MockContract.testCall.selector), composerCalldata
        );

        // composer calldata
        composerCalldata = CalldataLib.encodeExternalCall(address(callForwarder), uint256(0), false, composerCalldata);

        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(ShouldRevert.selector));
        composer.deltaCompose(composerCalldata);

        vm.stopPrank();

        // Verify assertions
        assertFalse(mockContract.called());
        assertFalse(mockContract.catchCalled());
    }

    function test_externalTryCall_catch_executes_if_not_successful() public {
        // Configure mock to fail
        mockContract.setShouldFail(true);
        mockContract.reset();

        // catch calldata, should be called in this test
        bytes memory composerCalldata =
            CalldataLib.encodeExternalCall(address(mockContract), uint256(0), false, abi.encodeWithSelector(MockContract.catchBlock.selector));

        // forwarder calldata
        composerCalldata = CalldataLib.encodeTryExternalCall(
            address(mockContract), uint256(0), false, false, abi.encodeWithSelector(MockContract.testCall.selector), composerCalldata
        );

        // composer calldata
        composerCalldata = CalldataLib.encodeExternalCall(address(callForwarder), uint256(0), false, composerCalldata);

        vm.startPrank(user);

        // should not revert
        composer.deltaCompose(composerCalldata);

        vm.stopPrank();

        // Verify assertions
        assertFalse(mockContract.called());
        assertTrue(mockContract.catchCalled());
    }

    function test_externalTryCall_catch_does_not_execute_if_successful() public {
        // Configure mock to fail
        mockContract.setShouldFail(false);
        mockContract.reset();

        // catch calldata, should not be called in this test
        bytes memory composerCalldata =
            CalldataLib.encodeExternalCall(address(mockContract), uint256(0), false, abi.encodeWithSelector(MockContract.catchBlock.selector));

        // forwarder calldata
        composerCalldata = CalldataLib.encodeTryExternalCall(
            address(mockContract), uint256(0), false, false, abi.encodeWithSelector(MockContract.testCall.selector), composerCalldata
        );

        // composer calldata
        composerCalldata = CalldataLib.encodeExternalCall(address(callForwarder), uint256(0), false, composerCalldata);

        vm.startPrank(user);

        // should not revert
        composer.deltaCompose(composerCalldata);

        vm.stopPrank();

        // Verify assertions
        assertTrue(mockContract.called());
        assertFalse(mockContract.catchCalled());
    }
}

// Helper contract to test try/catch

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
