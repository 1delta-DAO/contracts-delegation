// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";
import {DexPayConfig} from "contracts/1delta/modules/light/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

contract GmxLightTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 27970029;
    IComposerLike oneDV2;

    address internal constant GMX_POOL = 0xec8d8D4b215727f3476FF0ab41c406FA99b4272C;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;

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

    function gmxPoolWETHUSDCSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            WETH,
            false // no pre param
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.gmxStyleSwap(
            USDC,
            receiver,
            GMX_POOL,
            DexPayConfig.CALLER_PAYS //
        );
    }

    function test_light_swap_gmx_single() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = USDC;
        uint256 amount = 1.0e18;
        uint256 approxOut = 2004991436; // 2004.991436
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory swap = gmxPoolWETHUSDCSwap(
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
