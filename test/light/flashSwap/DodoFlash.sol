// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";

interface DVMF {
    function _REGISTRY_(address, address, uint256) external view returns (address);

    function getDODOPool(address, address) external view returns (address[] memory);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract DodoLightTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 27970029;
    OneDeltaComposerLight oneDV2;

    address internal constant DVM_FACTORY = 0x0226fCE8c969604C3A0AD19c37d1FAFac73e13c2;
    address internal constant DODO_WETH_JOJO = 0x0Df758CFe1DE840360a92424494776E8C7f29A9c;

    uint256 internal constant DODO_WETH_JOJO_INDEX = 0;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant SUPEROBETH = 0xDBFeFD2e8460a6Ee4955A68582F85708BAEA60A3;
    address internal constant JOJO = 0x0645bC5cDff2376089323Ac20Df4119e48e4BCc4;

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

    function dodPoolWETHJOJOSwap(address receiver, uint256 amount, bytes memory callbackData) internal view returns (bytes memory data) {
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
            CalldataLib.DodoSelector.SELL_QUOTE, // sell quote
            0,
            CalldataLib.DexPayConfig.FLASH, // payMode <- user pays
            callbackData
        );
    }

    function test_light_flash_swap_dodo_single() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = JOJO;
        uint256 amount = 1.0e18;
        uint256 approxOut = 21319114459675017318834;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);
        bytes memory transfer = CalldataLib.transferIn(
            tokenIn,
            DODO_WETH_JOJO,
            amount //
        );
        bytes memory swap = dodPoolWETHJOJOSwap(
            user,
            amount, //
            transfer
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }
}
