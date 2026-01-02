// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

// balancer V3 allows setting the callback selector oneself, we use this one
interface IBalancerV3CAllback {
    function balancerUnlockCallback(bytes calldata) external;
}

/**
 * Behaves like Uniswap V4
 */
contract FlashSwapTestBalancerSecurity is BaseTest {
    IComposerLike oneDV2;

    uint256 internal attackerPk = 0xbad0;
    address internal attacker = vm.addr(attackerPk);

    address internal USDC;
    address internal WETH;
    address internal constant ETH = address(0);

    uint256 internal constant forkBlock = 23969720;
    uint8 internal constant BALANCER_V3_POOL_ID = 0;

    address internal constant BALANCER_V3_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ETHEREUM_MAINNET;

        _init(chainName, forkBlock, true);
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    /**
     * Try calling the V4 callback directly
     */
    function test_security_flashSwap_swap_balancer_v3_callback_direct() external {
        address tokenIn = WETH;
        address tokenOut = USDC;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory stealFunds = CalldataLib.encodeTransferIn(tokenIn, attacker, IERC20All(tokenIn).balanceOf(user));

        vm.prank(attacker);
        vm.expectRevert("InvalidCaller()");
        IBalancerV3CAllback(address(oneDV2)).balancerUnlockCallback(
            abi.encodePacked(user, uint8(BALANCER_V3_POOL_ID), uint16(stealFunds.length), stealFunds)
        );
    }

    /**
     * Try calling the V4 callback directly, bad pool id here as fallthroug
     */
    function test_security_flashSwap_swap_balancer_v3_callback_direct_bad_id() external {
        address tokenIn = WETH;
        address tokenOut = USDC;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory stealFunds = CalldataLib.encodeTransferIn(tokenIn, attacker, IERC20All(tokenIn).balanceOf(user));

        vm.prank(attacker);
        vm.expectRevert("InvalidCaller()");
        IBalancerV3CAllback(address(oneDV2)).balancerUnlockCallback(
            abi.encodePacked(user, uint8(2), uint16(stealFunds.length), stealFunds)
        );
    }
}
