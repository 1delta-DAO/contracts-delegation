// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract BalancerLightTest is BaseTest {
    address internal constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    bytes32 internal constant WETH_RETH_PID = 0xc771c1a5905420daec317b154eb13e4198ba97d0000000000000000000000023;
    uint256 internal constant forkBlock = 27970029;
    OneDeltaComposerLight oneDV2;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant rETH = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = new OneDeltaComposerLight(address(0));
    }

    function balancerWethRethSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
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
            rETH,
            receiver,
            uint8(80), // DODO
            WETH_RETH_PID,
            BALANCER_V2_VAULT,
            uint8(0) // payMode <- user pays
        );
    }

    function test_light_swap_balancer_single() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = rETH;
        uint256 amount = 1.0e18;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = balancerWethRethSwap(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, amount, (amount * 20) / 100);
    }
}
