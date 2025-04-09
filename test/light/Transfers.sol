// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";
import {MorphoMathLib} from "./utils/MathLib.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import "./utils/CalldataLib.sol";
import {DeltaErrors} from "modules/shared/errors/Errors.sol";

contract TransfersLightTest is BaseTest, DeltaErrors {
    using MorphoMathLib for uint256;

    OneDeltaComposerLight oneD;

    uint256 internal constant forkBlock = 26696865;

    address internal MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal AAVE_V3_POOL;
    address internal GRANARY_POOL;
    address private BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address internal constant UNI_V4_PM = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    // balancer dex data
    address internal constant BALANCER_V3_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    address internal WETH;
    address internal USDC;

    function setUp() public virtual {
        _init(Chains.BASE, forkBlock);
        AAVE_V3_POOL = chain.getLendingController(Lenders.AAVE_V3);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        GRANARY_POOL = chain.getLendingController(Lenders.GRANARY);
        oneD = new OneDeltaComposerLight();
    }

    uint256 internal constant UPPER_BIT = 1 << 255;

    /**
     * Sweep amount in contract
     */
    function test_light_sweep_token_amount() external {
        address asset = WETH;
        uint256 sweepAm = 30.0e18;
        deal(asset, address(oneD), sweepAm);
        bytes memory sweep = CalldataLib.sweep(
            asset,
            user,
            sweepAm, //
            CalldataLib.SweepType.AMOUNT
        );
        uint256 balanceBefore = IERC20All(asset).balanceOf(user);

        vm.prank(user);
        oneD.deltaCompose(sweep);

        uint256 balanceAfter = IERC20All(asset).balanceOf(user);

        assertApproxEqAbs(balanceAfter - balanceBefore, sweepAm, 0, "Sweep failed");
    }

    function test_light_sweep_validate() external {
        uint256 initialAmount = 1000e6;
        uint256 minBalance = 500e6;

        deal(USDC, address(oneD), initialAmount);

        bytes memory data = CalldataLib.sweep(USDC, user, minBalance, CalldataLib.SweepType.VALIDATE);

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(IERC20All(USDC).balanceOf(user), initialAmount);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), 0);
    }

    function test_light_sweep_validate_reverts() external {
        uint256 initialAmount = 499e6;
        uint256 minBalance = 500e6;

        deal(USDC, address(oneD), initialAmount);

        bytes memory data = CalldataLib.sweep(USDC, user, minBalance, CalldataLib.SweepType.VALIDATE);

        vm.prank(user);
        vm.expectRevert(SLIPPAGE);
        oneD.deltaCompose(data);

        assertEq(IERC20All(USDC).balanceOf(user), 0);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), initialAmount);
    }

    function test_light_sweep_balance() external {
        uint256 initialAmount = 1000e6;
        deal(USDC, address(oneD), initialAmount);

        bytes memory data = CalldataLib.sweep(
            USDC,
            user,
            0, // minBalance
            CalldataLib.SweepType.VALIDATE
        );

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(IERC20All(USDC).balanceOf(user), initialAmount);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), 0);
    }

    function test_light_sweep_native() external {
        uint256 initialAmount = 1 ether;
        vm.deal(address(oneD), initialAmount);
        uint256 userInitialBalance = user.balance;

        // native sweep
        bytes memory data = CalldataLib.sweep(
            address(0),
            user,
            0, // min balance => all balance (for validate mode)
            CalldataLib.SweepType.VALIDATE
        );

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(user.balance, userInitialBalance + initialAmount);
        //assertEq(address(oneD).balance, 0);
    }

    function test_light_transfer_transferIn_zero() external {
        // zero means entire balance
        uint256 initialAmount = 1000e6;
        deal(USDC, user, initialAmount);

        vm.prank(user);
        IERC20All(USDC).approve(address(oneD), type(uint256).max);

        bytes memory data = CalldataLib.transferIn(USDC, address(oneD), 0);

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(IERC20All(USDC).balanceOf(user), 0);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), initialAmount);
    }

    function test_light_transfer_transferIn_specific() external {
        uint256 initialAmount = 1000e6;
        uint256 transferAmount = 500e6;
        deal(USDC, user, initialAmount);

        vm.prank(user);
        IERC20All(USDC).approve(address(oneD), type(uint256).max);

        bytes memory data = CalldataLib.transferIn(USDC, address(oneD), transferAmount);

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(IERC20All(USDC).balanceOf(user), initialAmount - transferAmount);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), transferAmount);
    }
}
