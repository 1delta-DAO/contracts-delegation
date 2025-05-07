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
    address public USDC;
    address public WETH;

    // Test amounts
    uint256 public BRIDGE_AMOUNT = 1000 * 1e6; // 1000 USDC
    uint256 public BRIDGE_AMOUNT_ETH = 0.1 ether;

    // Fee parameters
    uint128 public FIXED_FEE = 5 * 1e5; // 0.5 USDC
    uint128 public FEE_PERCENTAGE = 0; // 0%

    function setUp() public {
        rpcOverrides[Chains.ARBITRUM_ONE] = "https://arbitrum.rpc.subquery.network/public";

        _init(Chains.ARBITRUM_ONE, 333862337, true);

        callForwarder = new CallForwarder();

        composer = ComposerPlugin.getComposer(Chains.ARBITRUM_ONE);

        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        _fundUserWithToken(USDC, BRIDGE_AMOUNT);
        _fundUserWithNative(BRIDGE_AMOUNT_ETH);

        vm.label(address(callForwarder), "CallForwarder");
        vm.label(address(composer), "Composer");
        vm.label(SPOKE_POOL, "AcrossSpokePool");
        vm.label(USDC, "USDC");
        vm.label(WETH, "WETH");
        vm.label(user, "User");
    }

    function test_across_bridge_token() public {
        bytes memory message = new bytes(0);

        bytes memory forwarderCalldata = abi.encodePacked(
            CalldataLib.encodeApprove(USDC, SPOKE_POOL),
            CalldataLib.encodeAcrossBridgeV2(USDC, USDC, BRIDGE_AMOUNT, FIXED_FEE, FEE_PERCENTAGE, POLYGON_CHAIN_ID, user, message),
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
        bytes memory message = new bytes(0);

        bytes memory forwarderCalldata = abi.encodePacked(
            CalldataLib.encodeAcrossBridgeV2(
                address(0), WETH, BRIDGE_AMOUNT_ETH, uint128(0.001 ether), FEE_PERCENTAGE, POLYGON_CHAIN_ID, user, message
            ),
            CalldataLib.encodeSweep(address(0), user, 0, SweepType.VALIDATE) // sweep any remaining ETH
        );

        bytes memory composerCalldata = abi.encodePacked(CalldataLib.encodeExternalCall(address(callForwarder), BRIDGE_AMOUNT_ETH, forwarderCalldata));

        vm.startPrank(user);

        composer.deltaCompose{value: BRIDGE_AMOUNT_ETH}(composerCalldata);

        vm.stopPrank();
    }
}
