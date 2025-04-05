// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";

/** This is for TraderJoe / MerchantMoe LB */
contract LBLightTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 77869637;
    OneDeltaComposerLight oneDV2;

    address internal constant LB_USDE_USDT = 0x7ccD8a769d466340Fff36c6e10fFA8cf9077D988;

    address internal USDC;
    address internal WETH;
    address internal USDT;
    address internal USDE;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.MANTLE, forkBlock);
        USDE = chain.getTokenAddress(Tokens.USDE);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDT = chain.getTokenAddress(Tokens.USDT);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = new OneDeltaComposerLight();
    }

    function lbPoolUSDEUSDTSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            USDE,
            false // no pre param
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.lbStyleSwap(
            USDT,
            receiver,
            LB_USDE_USDT,
            true,
            CalldataLib.DexPayConfig.CALLER_PAYS //
        );
    }

    function test_light_swap_lb_single() external {
        vm.assume(user != address(0));

        address tokenIn = USDE;
        address tokenOut = USDT;
        uint256 amount = 100_000.0e18;
        uint256 approxOut = 99921167437; // 99921.167437
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = lbPoolUSDEUSDTSwap(
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
