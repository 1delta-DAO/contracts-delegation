// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {BaseTest} from "../shared/BaseTest.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import {DexTypeMappings} from "light/swappers/dex/DexTypeMappings.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";
import {DexPayConfig} from "light/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {MaliciousPoolV3} from "test/mocks/MaliciousPoolV3.sol";
import {MaliciousPoolV2} from "test/mocks/MaliciousPoolV2.sol";

contract CallDataInjection is BaseTest, DeltaErrors {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 28493852;

    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant UNI_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;

    IComposerLike composer;

    address internal WETH;
    address internal USDC;

    address internal WETH_USDC_500_POOL;
    address internal attacker;

    function setUp() public virtual {
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);

        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);

        composer = ComposerPlugin.getComposer(chainName);

        WETH_USDC_500_POOL = IF(UNI_FACTORY).getPool(WETH, USDC, 500);

        // create attacker and deal some tokens to attacker
        attacker = makeAddr("attacker");
        vm.deal(address(attacker), 1 ether);
        deal(WETH, address(attacker), 1 ether);
    }

    function test_integ_security_callbackInjection_injection_uniV3BadPool() public {
        MaliciousPoolV3 maliciousPool = new MaliciousPoolV3(
            address(user),
            address(attacker),
            WETH // token to steal
        );

        deal(WETH, address(user), 10 ether);
        deal(WETH, address(attacker), 10);

        vm.prank(attacker);
        IERC20(WETH).approve(address(composer), 10);

        // Victim approves composer, or approved composer in another tx
        vm.startPrank(user);
        IERC20(WETH).approve(address(composer), type(uint256).max);
        vm.stopPrank();

        bytes memory swapCall = CalldataLib.swapHead(10, 0, WETH).attachBranch(0, 0, new bytes(0)).encodeUniswapV3StyleSwap(
            USDC, address(attacker), 0, address(maliciousPool), 500, DexPayConfig.CALLER_PAYS, new bytes(0)
        );

        // Execute swap through the composer contract
        vm.startPrank(attacker);
        vm.expectRevert("Callback failed");
        composer.deltaCompose(swapCall);
        vm.stopPrank();
    }

    function test_integ_security_callbackInjection_injection_uniV3DirectInject() public {
        bytes4 uniV3CallbackSelector = bytes4(0xfa461e33);
        // deal weth to user and approve composer, simulating a prior tx on composer by the victim
        deal(WETH, address(user), 10 ether);
        vm.prank(user);
        IERC20(WETH).approve(address(composer), type(uint256).max);
        uint256 userInitialBalance = IERC20(WETH).balanceOf(address(user));

        bytes memory transferCall = CalldataLib.encodeTransferIn(WETH, attacker, userInitialBalance);
        bytes memory maliciousCall =
            abi.encodePacked(user, WETH, address(0), uint8(DexTypeMappings.UNISWAP_V3_ID), uint16(500), uint16(transferCall.length), transferCall);

        // try to execute the attack
        vm.startPrank(attacker);
        (bool success, bytes memory data) = address(composer).call(abi.encodeWithSelector(uniV3CallbackSelector, 1, 0, maliciousCall));
        vm.stopPrank();
        vm.assertEq(success, false);
        vm.assertEq(data, abi.encodeWithSignature("BadPool()"));
    }

    function test_integ_security_callbackInjection_injection_uniV2DirectInject() public {
        address weth_usdc_pool = IF2(UNI_V2_FACTORY).getPair(WETH, USDC);
        bytes4 uniV2SwapSelector = bytes4(0x022c0d9f);

        // Set up victim with tokens and approvals
        deal(WETH, address(user), 10 ether);
        vm.prank(user);
        IERC20(WETH).approve(address(composer), type(uint256).max);

        // Record initial balances
        uint256 victimInitialBalance = IERC20(WETH).balanceOf(address(user));

        bytes memory transferCall = CalldataLib.encodeTransferIn(WETH, attacker, victimInitialBalance);

        vm.prank(attacker);
        (bool success, bytes memory data) =
            address(weth_usdc_pool).call(abi.encodeWithSelector(uniV2SwapSelector, 1, 0, address(composer), transferCall));
        assertFalse(success);
        assertEq(data, abi.encodeWithSelector(INVALID_CALLER));
    }

    function test_integ_security_callbackInjection_injection_uniV2BadPool() public {
        MaliciousPoolV2 maliciousPool = new MaliciousPoolV2(
            address(user),
            address(attacker),
            WETH, // token to steal
            address(composer)
        );

        deal(WETH, address(user), 10 ether);
        deal(WETH, address(attacker), 1 ether); // Attacker needs some WETH to initiate swap
        vm.startPrank(attacker);
        IERC20(WETH).transfer(address(composer), 10);

        composer.deltaCompose(
            abi.encodePacked(
                CalldataLib.swapHead(10, 0, WETH).attachBranch(0, 0, new bytes(0)),
                CalldataLib.encodeUniswapV2StyleSwap(USDC, attacker, 0, address(maliciousPool), 9970, DexPayConfig.PRE_FUND, new bytes(1111))
            )
        );
        vm.stopPrank();
    }
}

// Helper contracts and interfaces
// -------------------------------------------------------------------------------------------------
interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IF2 {
    function getPair(address, address) external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
