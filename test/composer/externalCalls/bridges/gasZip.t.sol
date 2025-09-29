// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {CallForwarder} from "contracts/1delta/composer/generic/CallForwarder.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {console} from "forge-std/console.sol";

contract GasZipTest is BaseTest {
    using CalldataLib for bytes;

    event Deposit(address from, uint256 chains, uint256 amount, bytes32 to);

    CallForwarder private callForwarder;
    IComposerLike private composer;
    address private gasZipRouter = 0x2a37D63EAdFe4b4682a3c28C1c2cD4F109Cc2762;

    function setUp() public {
        rpcOverrides[Chains.ETHEREUM_MAINNET] = "wss://0xrpc.io/eth";
        _init(Chains.ETHEREUM_MAINNET, 0, true);

        callForwarder = new CallForwarder();

        composer = ComposerPlugin.getComposer(Chains.ETHEREUM_MAINNET);

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(composer), "Composer");
        vm.label(gasZipRouter, "gasZipRouter");
    }

    function test_gaszip_bridge() public {
        deal(address(callForwarder), 1 ether);
        bytes memory data = CalldataLib.encodeGasZipEvmBridge(gasZipRouter, user, 1 ether, 10);
        data = CalldataLib.encodeExternalCall(address(callForwarder), 0, false, data);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Deposit(address(callForwarder), 10, 1 ether, bytes32(bytes20(uint160(user))));

        composer.deltaCompose(data);
    }

    function test_gaszip_bridge_balance() public {
        deal(address(callForwarder), 1 ether);
        bytes memory data = CalldataLib.encodeGasZipEvmBridge(gasZipRouter, user, 0, 10);
        data = CalldataLib.encodeExternalCall(address(callForwarder), 0, false, data);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Deposit(address(callForwarder), 10, 1 ether, bytes32(bytes20(uint160(user))));

        composer.deltaCompose(data);
    }

    function test_gaszip_mock() public {
        deal(address(callForwarder), 1 ether);
        GasZipMock gz = new GasZipMock(10, bytes32(bytes20(uint160(user))), 1 ether);
        vm.label(address(gz), "GasZipMock");
        bytes memory data = CalldataLib.encodeGasZipEvmBridge(address(gz), user, 1 ether, 10);
        data = CalldataLib.encodeExternalCall(address(callForwarder), 0, false, data);

        vm.prank(user);
        composer.deltaCompose(data);
    }
}

contract GasZipMock {
    constructor(uint256 destinationChains, bytes32 to, uint256 amount) {
        expectedDestinationChains = destinationChains;
        expectedTo = to;
        expectedAmount = amount;
    }

    uint256 public expectedDestinationChains;
    bytes32 public expectedTo;
    uint256 public expectedAmount;

    function deposit(uint256 destinationChains, bytes32 to) external payable {
        if (destinationChains != expectedDestinationChains) {
            console.log("Invalid destination chain", destinationChains);
            revert("Invalid destination chain");
        }
        if (to != expectedTo) {
            revert("Invalid receiver");
        }
        if (msg.value != expectedAmount) {
            revert("Invalid amount");
        }
    }
}
