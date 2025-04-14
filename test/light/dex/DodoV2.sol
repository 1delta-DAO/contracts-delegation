// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";
import {DexPayConfig, DodoSelector} from "contracts/1delta/modules/light/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
/**
 * Test DodoV2 simple swaps
 */

contract DodoV2LightTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 27970029;
    IComposerLike oneDV2;

    address internal constant DODO_WETH_JOJO = 0x0Df758CFe1DE840360a92424494776E8C7f29A9c;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant SUPEROBETH = 0xDBFeFD2e8460a6Ee4955A68582F85708BAEA60A3;
    address internal constant JOJO = 0x0645bC5cDff2376089323Ac20Df4119e48e4BCc4;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BASE;
        
        _init(chainName, forkBlock);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function dodoPoolWETHJOJOSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            WETH,
            false // no pre param
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.dodoStyleSwap(
            JOJO,
            receiver,
            DODO_WETH_JOJO,
            DodoSelector.SELL_QUOTE, // sell quote
            0,
            DexPayConfig.CALLER_PAYS, // payMode <- user pays
            hex""
        );
    }

    function test_light_swap_dodo_single() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = JOJO;
        uint256 amount = 1.0e18;
        uint256 approxOut = 21319114459675017318834;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory swap = dodoPoolWETHJOJOSwap(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }
}
