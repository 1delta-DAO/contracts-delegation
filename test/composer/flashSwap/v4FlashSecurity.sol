// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {DexPayConfig, SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IUnlockCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

/**
 * Uniswap V3 Security tests
 * - the onbly attack vector is calling the callback directly
 * - the PM always sends the callback to msg.sender
 * - as such, the call will revert in case any address but the pool manager calls it
 */
contract FlashSwapTestV4Security is BaseTest {
    using CalldataLib for bytes;

    uint256 internal attackerPk = 0xbad0;
    address internal attacker = vm.addr(attackerPk);

    IComposerLike oneDV2;

    address internal USDC;
    address internal WETH;
    address internal constant ETH = address(0);

    uint256 internal constant forkBlock = 23969720;
    uint8 internal constant UNISWAP_V4_POOL_ID = 0;

    address internal constant UNI_V4_PM = 0x000000000004444c5dc75cB358380D2e3dE08A90;

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
    function test_security_flashSwap_swap_v4_callback_direct() external {
        address tokenIn = WETH;
        address tokenOut = USDC;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory stealFunds = CalldataLib.encodeTransferIn(tokenIn, attacker, IERC20All(tokenIn).balanceOf(user));

        vm.prank(attacker);
        vm.expectRevert("InvalidCaller()");
        IUnlockCallback(address(oneDV2)).unlockCallback(
            abi.encodePacked(user, uint8(UNISWAP_V4_POOL_ID), uint16(stealFunds.length), stealFunds)
        );
    }

    /**
     * Try calling the V4 callback directly, bad pool id here as fallthroug
     */
    function test_security_flashSwap_swap_v4_callback_direct_bad_id() external {
        address tokenIn = WETH;
        address tokenOut = USDC;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory stealFunds = CalldataLib.encodeTransferIn(tokenIn, attacker, IERC20All(tokenIn).balanceOf(user));

        vm.prank(attacker);
        vm.expectRevert("InvalidCaller()");
        IUnlockCallback(address(oneDV2)).unlockCallback(abi.encodePacked(user, uint8(2), uint16(stealFunds.length), stealFunds));
    }
}
