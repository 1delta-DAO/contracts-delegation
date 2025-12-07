// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CallForwarder} from "contracts/1delta/composer/generic/CallForwarder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {MockSquidRouter} from "test/mocks/MockSquidRouter.sol";

contract SquidRouterTest is Test {
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

    function encodeSquidRouterCall(address gateway, uint256 amount) internal returns (bytes memory) {
        string memory destChain = "polygon";
        string memory destAddress = "destinationAddress";
        string memory symbol = "USDC";
        bytes memory payload = hex"1de17ababe";
        address refundRecipient = user;
        bool enableExpress = true;

        vm.deal(address(composer), 1e10);

        MockSquidRouter(gateway).setExpectedSquidCall(symbol, BRIDGE_AMOUNT, destChain, destAddress, payload, refundRecipient, enableExpress, 1e10);

        return CalldataLib.encodeExternalCall(
            address(callForwarder),
            1e10,
            false,
            CalldataLib.encodeSquidRouterCall(
                USDC, address(gateway), bytes(symbol), amount, bytes(destChain), bytes(destAddress), payload, refundRecipient, enableExpress, 1e10
            )
        );
    }

    function test_unit_externalCall_squid_router_bridge_call_amount() public {
        MockSquidRouter gateway = new MockSquidRouter();
        vm.label(address(gateway), "MockSquidRouter");

        bytes memory composerCalldata = encodeSquidRouterCall(address(gateway), BRIDGE_AMOUNT);

        vm.startPrank(user);
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }

    function test_unit_externalCall_squid_router_bridge_call_balance() public {
        MockSquidRouter gateway = new MockSquidRouter();
        vm.label(address(gateway), "MockSquidRouter");

        bytes memory composerCalldata = encodeSquidRouterCall(address(gateway), 0);
        vm.mockCall(USDC, abi.encodeWithSelector(IERC20.balanceOf.selector, address(callForwarder)), abi.encode(BRIDGE_AMOUNT));

        vm.startPrank(user);
        composer.deltaCompose(composerCalldata);
        vm.stopPrank();
    }
}
