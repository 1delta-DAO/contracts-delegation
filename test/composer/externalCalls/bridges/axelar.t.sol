// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CallForwarder} from "contracts/1delta/composer/generic/CallForwarder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CalldataLib} from "test/composer/utils/CalldataLib.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {MockAxelar} from "./MockAxelar.sol";

contract AxelarTest is Test {
    using CalldataLib for bytes;

    CallForwarder private callForwarder;
    IComposerLike private composer;

    address public USDC = 0x1234000000000000000000000000000000000000;
    address public user = 0x1234500000000000000000000000000000000000;
    uint256 public BRIDGE_AMOUNT = 1000 * 1e6;

    function setUp() public {
        vm.deal(user, 100 ether);
        callForwarder = new CallForwarder();
        composer = ComposerPlugin.getComposer(Chains.ARBITRUM_ONE);

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(composer), "Composer");
        vm.label(USDC, "USDC");
        vm.label(user, "User");
    }

    function test_axelar_send_token_amount() public {
        MockAxelar gateway = new MockAxelar();
        vm.label(address(gateway), "MockAxelarGateway");

        // not following Axelar's requirements (mock values)
        string memory destChain = "polygon";
        string memory destAddress = "destinationAddress";
        string memory symbol = "USDC";

        gateway.setExpectedSendToken(destChain, destAddress, symbol, BRIDGE_AMOUNT);

        bytes memory composerCalldata = CalldataLib.encodeExternalCall(
            address(callForwarder),
            0,
            false,
            CalldataLib.encodeAxelarSendToken(USDC, address(gateway), bytes(destChain), bytes(destAddress), bytes(symbol), BRIDGE_AMOUNT)
        );

        vm.startPrank(user);
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }

    function test_axelar_send_token_balance() public {
        MockAxelar gateway = new MockAxelar();
        vm.label(address(gateway), "MockAxelarGateway");

        string memory destChain = "polygon";
        string memory destAddress = "destinationAddress";
        string memory symbol = "USDC";

        gateway.setExpectedSendToken(destChain, destAddress, symbol, BRIDGE_AMOUNT);

        bytes memory composerCalldata = CalldataLib.encodeExternalCall(
            address(callForwarder),
            0,
            false,
            CalldataLib.encodeAxelarSendToken(USDC, address(gateway), bytes(destChain), bytes(destAddress), bytes(symbol), 0)
        );

        vm.mockCall(USDC, abi.encodeWithSelector(IERC20.balanceOf.selector, address(callForwarder)), abi.encode(BRIDGE_AMOUNT));

        vm.startPrank(user);
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }

    function test_axelar_call_contract_with_token_amount() public {
        MockAxelar gateway = new MockAxelar();
        vm.label(address(gateway), "MockAxelarGateway");

        string memory destChain = "polygon";
        string memory contractAddr = "contractAddress";
        bytes memory payload = hex"cafebabe01";
        string memory symbol = "USDC";

        gateway.setExpectedCallContractWithToken(destChain, contractAddr, payload, symbol, BRIDGE_AMOUNT);

        bytes memory composerCalldata = CalldataLib.encodeExternalCall(
            address(callForwarder),
            0,
            false,
            CalldataLib.encodeAxelarCallContractWithToken(
                USDC, address(gateway), bytes(destChain), bytes(contractAddr), payload, bytes(symbol), BRIDGE_AMOUNT
            )
        );

        vm.startPrank(user);
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }

    function test_axelar_call_contract_with_token_balance() public {
        MockAxelar gateway = new MockAxelar();
        vm.label(address(gateway), "AxelarGateway");

        string memory destChain = "polygon";
        string memory contractAddr = "contractAddress";
        bytes memory payload = hex"00ff00";
        string memory symbol = "USDC";

        gateway.setExpectedCallContractWithToken(destChain, contractAddr, payload, symbol, BRIDGE_AMOUNT);

        bytes memory composerCalldata = CalldataLib.encodeExternalCall(
            address(callForwarder),
            0,
            false,
            CalldataLib.encodeAxelarCallContractWithToken(
                USDC,
                address(gateway),
                bytes(destChain),
                bytes(contractAddr),
                payload,
                bytes(symbol),
                0 // balance sentinel
            )
        );

        vm.startPrank(user);
        vm.mockCall(USDC, abi.encodeWithSelector(IERC20.balanceOf.selector, address(callForwarder)), abi.encode(BRIDGE_AMOUNT));
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }
}
