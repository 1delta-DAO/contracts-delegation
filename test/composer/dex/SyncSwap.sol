// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import "../../../contracts/1delta/composer//quoter/QuoterLight.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";
import {DexPayConfig} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
/**
 * This is for SyncSwap (Ritsu on Taiko)
 */

contract SyncSwapLightTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 536078;
    QuoterLight quoter;
    IComposerLike oneDV2;

    address internal constant RITSU_USDC_WETH = 0x424Fab7bfA3E3Dd0e5BB96771fFAa72fe566200e;

    address internal USDC;
    address internal WETH;
    address internal USDT;

    function setUp() public virtual {
        string memory chainName = Chains.TAIKO_ALETHIA;
        // initialize the chain
        _init(chainName, forkBlock);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDT = chain.getTokenAddress(Tokens.USDT);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = ComposerPlugin.getComposer(chainName);
        quoter = new QuoterLight();
    }

    function syncPoolWETHUSDCSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            WETH
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeSyncSwapStyleSwap(
            USDC,
            receiver,
            RITSU_USDC_WETH,
            DexPayConfig.CALLER_PAYS //
        );
    }

    function test_light_swap_sync_single() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = USDC;
        uint256 amount = 1.0e18;
        uint256 approxOut = 2129321676; // 2129.321676 USDC
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory swap = syncPoolWETHUSDCSwap(
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
