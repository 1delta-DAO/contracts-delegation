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
 * This is for TraderJoe / MerchantMoe LB
 */
contract LBLightTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 77869637;

    QuoterLight quoter;
    IComposerLike oneDV2;

    address internal constant LB_USDE_USDT = 0x7ccD8a769d466340Fff36c6e10fFA8cf9077D988;

    address internal USDC;
    address internal WETH;
    address internal USDT;
    address internal USDE;

    function setUp() public virtual {
        string memory chainName = Chains.MANTLE;
        // initialize the chain
        _init(chainName, forkBlock, true);
        USDE = chain.getTokenAddress(Tokens.USDE);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDT = chain.getTokenAddress(Tokens.USDT);
        USDC = chain.getTokenAddress(Tokens.USDC);
        // we can use base here as the LB is not chain-dependent
        oneDV2 = ComposerPlugin.getComposer(Chains.BASE);
        quoter = new QuoterLight();
    }

    function lbPoolUSDEUSDTSwapPath(address receiver) internal view returns (bytes memory data) {
        data = abi.encodePacked(USDE).attachBranch(
            0,
            0, //
            hex""
        );
        data = data.encodeLbStyleSwap(
            USDT,
            receiver,
            LB_USDE_USDT,
            true,
            DexPayConfig.CALLER_PAYS //
        );
    }

    function lbPoolUSDEUSDTSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            USDE
        );
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeLbStyleSwap(
            USDT,
            receiver,
            LB_USDE_USDT,
            true,
            DexPayConfig.CALLER_PAYS //
        );
    }

    function test_light_swap_lb_single() external {
        vm.assume(user != address(0));

        address tokenIn = USDE;
        address tokenOut = USDT;
        uint256 amount = 100_000.0e18;
        uint256 approxOut = 99921167437; // 99921.167437
        deal(tokenIn, user, amount);

        bytes memory data = lbPoolUSDEUSDTSwapPath(address(0));

        uint256 quoted = quoter.quote(amount, data);
        console.log("quoted", quoted);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory swap = lbPoolUSDEUSDTSwap(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, quoted, 0);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }
}
