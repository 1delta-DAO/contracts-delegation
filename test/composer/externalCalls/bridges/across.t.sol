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
import {IAcrossSpokePool} from "contracts/1delta/composer/generic/bridges/Across/IAcross.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

contract AcrossTest is BaseTest {
    using CalldataLib for bytes;

    // Contract instances
    CallForwarder private callForwarder;
    IComposerLike private composer;

    // Across contracts on Arbitrum
    address public constant SPOKE_POOL = 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A;

    // Test parameters
    uint32 public constant POLYGON_CHAIN_ID = 137;
    address public constant POLYGON_USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address public USDC;
    address public WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; // on polygon
    address public WETH9_arb = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // Test amounts
    uint256 public BRIDGE_AMOUNT = 1000 * 1e6; // 1000 USDC

    // Fee parameters
    uint128 public FIXED_FEE = 5 * 1e5; // 0.5 USDC
    uint32 public FEE_PERCENTAGE = 10e7; // 10% (100% is 1e9)

    function setUp() public {
        rpcOverrides[Chains.ARBITRUM_ONE] = "https://arbitrum.rpc.subquery.network/public";

        _init(Chains.ARBITRUM_ONE, 0, true);

        callForwarder = new CallForwarder();

        composer = ComposerPlugin.getComposer(Chains.ARBITRUM_ONE);

        USDC = chain.getTokenAddress(Tokens.USDC);

        _fundUserWithToken(USDC, BRIDGE_AMOUNT);

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(composer), "Composer");
        vm.label(SPOKE_POOL, "AcrossSpokePool");
        vm.label(USDC, "Arbitrum USDC");
        vm.label(WETH, "Polygon WETH");
        vm.label(user, "User");
        vm.label(POLYGON_USDC, "Polygon USDC");
        vm.label(WETH9_arb, "Arbitrum WETH9");
    }

    function test_across_bridge_token() public {
        bytes memory message = new bytes(0);

        bytes memory forwarderCalldata = abi.encodePacked(
            CalldataLib.encodeApprove(USDC, SPOKE_POOL),
            CalldataLib.encodeAcrossBridge(SPOKE_POOL, USDC, POLYGON_USDC, 0, FIXED_FEE, FEE_PERCENTAGE, POLYGON_CHAIN_ID, user, message),
            CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE)
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

    function test_across_bridge_native() public {
        uint256 eth_amount = 1 ether;
        uint128 fee = 0.001 ether;

        bytes memory message = new bytes(0);

        deal(address(composer), eth_amount + fee);

        bytes memory forwarderCalldata = abi.encodePacked(
            CalldataLib.encodeAcrossBridge(SPOKE_POOL, WETH9_arb, WETH, 0, fee, FEE_PERCENTAGE, POLYGON_CHAIN_ID, user, message),
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE) // sweep any remaining ETH
        );

        bytes memory composerCalldata = abi.encodePacked(
            CalldataLib.encodeSweep(address(0), address(callForwarder), 0, SweepType.VALIDATE), // transfer all eth to call forwarder
            CalldataLib.encodeExternalCall(address(callForwarder), 0, forwarderCalldata)
        );

        vm.startPrank(user);

        composer.deltaCompose(composerCalldata);

        vm.stopPrank();
    }
}
