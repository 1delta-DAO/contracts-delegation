// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";

/**
 * We test Curve single swaps
 */
contract CurveLightTest is BaseTest {
    uint256 internal constant forkBlock = 27970029;
    OneDeltaComposerLight oneDV2;

    uint8 internal constant EXCHANGE_UNDERLYING_SELECTOR_WITH_RECEIVER = 6;
    uint8 internal constant EXCHANGE_UNDERLYING_NATIVE_IN_SELECTOR_WITH_RECEIVER = 8;
    uint8 internal constant EXCHANGE_RECEIVED_INT_WITH_RECEIVER = 0;
    uint8 internal constant EXCHANGE = 3; // uses use_eth=false at all times

    address internal constant TRY_CRYPTO_CRV_USD_ETH = 0x11C1fBd4b3De66bC0565779b35171a6CF3E71f59;
    address internal constant SUPEROBETH_WETH_NG = 0x302A94E3C28c290EAF2a4605FC52e11Eb915f378;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant SUPEROBETH = 0xDBFeFD2e8460a6Ee4955A68582F85708BAEA60A3;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = new OneDeltaComposerLight();
    }

    function curvePoolETHcbETHSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            uint128(1), //
            WETH,
            uint8(0), // swaps max index
            uint8(0) // splits
            // single split data (no data here)
            // uint8(0), // swaps max index for inner path
        );
        data = abi.encodePacked(
            data,
            cbETH,
            receiver,
            uint8(DexTypeMappings.CURVE_V1_STANDARD_ID),
            TRY_CRYPTO_CRV_USD_ETH,
            uint8(0),
            uint8(1),
            EXCHANGE,
            uint16(0) // payMode <- user pays
        );
    }

    function curvePoolcbETHETHSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            uint128(1), //
            cbETH,
            uint8(0), // swaps max index
            uint8(0) // splits
            // single split data (no data here)
            // uint8(0), // swaps max index for inner path
        );
        data = abi.encodePacked(
            data,
            WETH,
            receiver,
            uint8(DexTypeMappings.CURVE_V1_STANDARD_ID),
            TRY_CRYPTO_CRV_USD_ETH,
            uint8(1),
            uint8(0),
            EXCHANGE,
            uint16(0) // payMode <- user pays
        );
    }

    function curvePoolNGUSDCUSDMSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            uint128(1), //
            WETH,
            uint8(0), // swaps max index
            uint8(0) // splits
            // single split data (no data here)
            // uint8(0), // swaps max index for inner path
        );
        data = abi.encodePacked(
            data,
            SUPEROBETH,
            receiver,
            uint8(DexTypeMappings.CURVE_RECEIVED_ID), // NG
            SUPEROBETH_WETH_NG,
            uint8(0),
            uint8(1),
            EXCHANGE_RECEIVED_INT_WITH_RECEIVER,
            uint16(0) // payMode <- user pays
        );
    }

    function test_light_swap_curve_single_eth_in() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = cbETH;
        uint256 amount = 2.0e18;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = curvePoolETHcbETHSwap(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, amount, 0.2e18);
    }

    function test_light_swap_curve_single_reverse() external {
        vm.assume(user != address(0));

        address tokenIn = cbETH;
        address tokenOut = WETH;
        uint256 amount = 2.0e18;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = curvePoolcbETHETHSwap(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, amount, 0.2e18);
    }

    function test_light_swap_curve_single_ng() external {
        vm.assume(user != address(0));
        address tokenIn = WETH;
        address tokenOut = SUPEROBETH;
        uint256 amount = 1.0e18;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = curvePoolNGUSDCUSDMSwap(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);

        assertApproxEqAbs(balAfter - balBefore, amount, 0.01e18);
    }
}
