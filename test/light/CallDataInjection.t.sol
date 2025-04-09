// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {BaseTest} from "../shared/BaseTest.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {OneDeltaComposerLight} from "light/Composer.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import {DexTypeMappings} from "light/swappers/dex/DexTypeMappings.sol";
import {CalldataLib} from "./utils/CalldataLib.sol";
import {DeltaErrors} from "modules/shared/errors/Errors.sol";

contract CallDataInjection is BaseTest, DeltaErrors {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 28493852;

    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant UNI_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;

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

    function test_light_callback_injection_uniV3_bad_pool() public {
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

        bytes memory swapCall = CalldataLib.swapHead(10, 0, WETH, false).attachBranch(0, 0, new bytes(0))
            .uniswapV3StyleSwap(
            USDC, address(attacker), 0, address(maliciousPool), 500, CalldataLib.DexPayConfig.CALLER_PAYS, new bytes(0)
        );

        // Execute swap through the composer contract
        vm.startPrank(attacker);
        vm.expectRevert("Callback failed");
        composer.deltaCompose(swapCall);
        vm.stopPrank();
    }

    function test_light_callback_injection_uniV3_direct_inject() public {
        bytes4 uniV3CallbackSelector = bytes4(0xfa461e33);
        // deal weth to user and approve composer, simulating a prior tx on composer by the victim
        deal(WETH, address(user), 10 ether);
        vm.prank(user);
        IERC20(WETH).approve(address(composer), type(uint256).max);
        uint256 userInitialBalance = IERC20(WETH).balanceOf(address(user));

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
        (bool success, bytes memory data) =
            address(composer).call(abi.encodeWithSelector(uniV3CallbackSelector, 1, 0, maliciousCall));
        vm.stopPrank();
        vm.assertEq(success, false);
        vm.assertEq(data, abi.encodeWithSignature("BadPool()"));
    }

    function test_light_callback_injection_uniV2_direct_inject() public {
        address weth_usdc_pool = IF2(UNI_V2_FACTORY).getPair(WETH, USDC);
        bytes4 uniV2SwapSelector = bytes4(0x022c0d9f);

        // Set up victim with tokens and approvals
        deal(WETH, address(user), 10 ether);
        vm.prank(user);
        IERC20(WETH).approve(address(composer), type(uint256).max);

        // Record initial balances
        uint256 victimInitialBalance = IERC20(WETH).balanceOf(address(user));

        bytes memory transferCall = CalldataLib.transferIn(WETH, attacker, victimInitialBalance);

        vm.prank(attacker);
        (bool success, bytes memory data) = address(weth_usdc_pool).call(
            abi.encodeWithSelector(uniV2SwapSelector, 1, 0, address(composer), transferCall)
        );
        assertFalse(success);
        assertEq(data, abi.encodeWithSelector(INVALID_CALLER));
    }

    function test_light_callback_injection_uniV2_bad_pool() public {
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
                CalldataLib.swapHead(10, 0, WETH, false).attachBranch(0, 0, new bytes(0)),
                CalldataLib.uniswapV2StyleSwap(
                    USDC, attacker, 0, address(maliciousPool), 9970, CalldataLib.DexPayConfig.PRE_FUND, new bytes(1111)
                )
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

interface IOneDeltaComposer {
    function uniswapV2SwapCallback(uint256 amount0Out, uint256 amount1Out, bytes calldata path, bytes calldata data)
        external;
}

contract MaliciousPoolV3 {
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
        (bool success,) = msg.sender.call(
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

contract MaliciousPoolV2 {
    address public victim;
    address public attacker;
    address public tokenToSteal;
    IOneDeltaComposer public composer;

    address private constant FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;

    constructor(address _victim, address _attacker, address _tokenToSteal, address _composer) {
        victim = _victim;
        attacker = _attacker;
        tokenToSteal = _tokenToSteal;
        composer = IOneDeltaComposer(_composer);
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (1156865411772232563819, 1695099113977, 1743777051);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        uint256 victimBalance = IERC20(tokenToSteal).balanceOf(victim);
        require(victimBalance > 0, "MaliciousPoolV2: Victim has no balance");

        _attemptAttack(victimBalance);
    }

    function _attemptAttack(uint256 victimBalance) internal {
        bytes memory transferCall = CalldataLib.transferIn(tokenToSteal, attacker, victimBalance);

        bytes memory maliciousCallbackData = abi.encodePacked(
            victim,
            tokenToSteal,
            address(0),
            uint112(victimBalance),
            uint8(0),
            uint16(transferCall.length),
            transferCall
        );

        (bool success,) = address(composer).call(
            abi.encodeWithSelector(
                bytes4(0x10d1e85c), address(composer), uint256(1), uint256(0), new bytes(0), maliciousCallbackData
            )
        );
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        IERC20(tokenToSteal).transferFrom(from, to, value);
        return true;
    }
}
