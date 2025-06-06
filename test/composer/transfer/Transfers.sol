// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";
import {StdStyle as S} from "forge-std/StdStyle.sol";
import {MorphoMathLib} from "test/composer/lending/utils/MathLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

contract TransfersLightTest is BaseTest, DeltaErrors {
    using MorphoMathLib for uint256;

    IComposerLike oneD;

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
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);
        AAVE_V3_POOL = chain.getLendingController(Lenders.AAVE_V3);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        GRANARY_POOL = chain.getLendingController(Lenders.GRANARY);
        oneD = ComposerPlugin.getComposer(chainName);
    }

    uint256 internal constant UPPER_BIT = 1 << 255;

    // ------------------------------------------------------------------------
    // sweep tests
    // ------------------------------------------------------------------------

    function test_light_sweep_token_amount() external {
        address asset = WETH;
        uint256 sweepAm = 30.0e18;
        deal(asset, address(oneD), sweepAm);
        bytes memory sweep = CalldataLib.encodeSweep(
            asset,
            user,
            sweepAm, //
            SweepType.AMOUNT
        );
        uint256 balanceBefore = IERC20All(asset).balanceOf(user);

        vm.prank(user);
        oneD.deltaCompose(sweep);

        uint256 balanceAfter = IERC20All(asset).balanceOf(user);

        assertApproxEqAbs(balanceAfter - balanceBefore, sweepAm, 0, "Sweep failed");
    }

    function test_light_sweep_validate() external {
        console.log(S.bold(S.blue("test sweep validate")));
        uint256 initialAmount = 1000e6;
        uint256 minBalance = 500e6;

        deal(USDC, address(oneD), initialAmount);
        console.log(S.yellow("initial balance of user: "), IERC20All(USDC).balanceOf(user));
        console.log(S.yellow("initial balance of oneD: "), IERC20All(USDC).balanceOf(address(oneD)));

        bytes memory data = CalldataLib.encodeSweep(USDC, user, minBalance, SweepType.VALIDATE);

        vm.prank(user);
        oneD.deltaCompose(data);
        console.log(S.green("balance of user after: "), IERC20All(USDC).balanceOf(user));
        console.log(S.green("balance of oneD after: "), IERC20All(USDC).balanceOf(address(oneD)));

        assertEq(IERC20All(USDC).balanceOf(user), initialAmount);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), 0);
        console.log(S.green("--------------------------------"));
    }

    function test_light_sweep_validate_reverts() external {
        uint256 initialAmount = 499e6;
        uint256 minBalance = 500e6;

        deal(USDC, address(oneD), initialAmount);

        bytes memory data = CalldataLib.encodeSweep(USDC, user, minBalance, SweepType.VALIDATE);

        vm.prank(user);
        vm.expectRevert(SLIPPAGE);
        oneD.deltaCompose(data);

        assertEq(IERC20All(USDC).balanceOf(user), 0);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), initialAmount);
    }

    function test_light_sweep_balance() external {
        uint256 initialAmount = 1000e6;
        deal(USDC, address(oneD), initialAmount);

        bytes memory data = CalldataLib.encodeSweep(
            USDC,
            user,
            0, // minBalance
            SweepType.VALIDATE
        );

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(IERC20All(USDC).balanceOf(user), initialAmount);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), 0);
    }

    function test_light_sweep_native_balance() external {
        uint256 initialAmount = 1 ether;
        vm.deal(address(oneD), initialAmount);
        uint256 userInitialBalance = user.balance;

        // native sweep
        bytes memory data = CalldataLib.encodeSweep(
            address(0),
            user,
            0, // min balance => all balance (for validate mode)
            SweepType.VALIDATE
        );

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(user.balance, userInitialBalance + initialAmount);
        assertEq(address(oneD).balance, 0);
    }

    function test_light_sweep_native_amount() external {
        uint256 initialAmount = 1 ether;
        uint256 sweepAmount = 0.5 ether;
        vm.deal(address(oneD), initialAmount);
        uint256 userInitialBalance = user.balance;

        bytes memory data = CalldataLib.encodeSweep(address(0), user, sweepAmount, SweepType.AMOUNT);

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(user.balance, userInitialBalance + sweepAmount);
        assertEq(address(oneD).balance, initialAmount - sweepAmount);
    }

    function test_light_sweep_native_amount_reverts_amount_mode() external {
        uint256 initialAmount = 1 ether;
        uint256 sweepAmount = 5 ether;
        vm.deal(address(oneD), initialAmount);

        bytes memory data = CalldataLib.encodeSweep(address(0), user, sweepAmount, SweepType.AMOUNT);

        vm.expectRevert(NATIVE_TRANSFER);
        vm.prank(user);
        oneD.deltaCompose(data);
    }

    function test_light_sweep_native_amount_reverts_validate_mode() external {
        uint256 initialAmount = 1 ether;
        uint256 sweepAmount = 5 ether;
        vm.deal(address(oneD), initialAmount);

        bytes memory data = CalldataLib.encodeSweep(address(0), user, sweepAmount, SweepType.VALIDATE);

        vm.expectRevert(SLIPPAGE);
        vm.prank(user);
        oneD.deltaCompose(data);
    }

    // ------------------------------------------------------------------------
    // transfer tests
    // ------------------------------------------------------------------------

    function test_light_transfer_transferIn_zero() external {
        // zero means entire balance
        uint256 initialAmount = 1000e6;
        deal(USDC, user, initialAmount);

        vm.prank(user);
        IERC20All(USDC).approve(address(oneD), type(uint256).max);

        bytes memory data = CalldataLib.encodeTransferIn(USDC, address(oneD), 0);

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

        bytes memory data = CalldataLib.encodeTransferIn(USDC, address(oneD), transferAmount);

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(IERC20All(USDC).balanceOf(user), initialAmount - transferAmount);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), transferAmount);
    }

    // ------------------------------------------------------------------------
    // wrap/unwrap tests
    // ------------------------------------------------------------------------

    function test_light_transfer_wrap_unwrap() external {
        // wrap
        uint256 initialAmount = 1 ether;
        vm.deal(address(oneD), initialAmount);

        bytes memory wrapData = CalldataLib.encodeWrap(initialAmount, WETH);

        vm.prank(user);
        oneD.deltaCompose(wrapData);

        assertEq(address(oneD).balance, 0);
        assertEq(IERC20All(WETH).balanceOf(address(oneD)), initialAmount);

        // Then unwrap
        bytes memory unwrapData = CalldataLib.encodeUnwrap(WETH, user, 0, SweepType.VALIDATE);

        uint256 userInitialBalance = user.balance;

        vm.prank(user);
        oneD.deltaCompose(unwrapData);

        assertEq(user.balance, userInitialBalance + initialAmount);
        assertEq(IERC20All(WETH).balanceOf(address(oneD)), 0);
    }

    // ------------------------------------------------------------------------
    // approval tests
    // ------------------------------------------------------------------------

    function test_light_transfer_approve() external {
        uint256 initialAmount = 1000e6;
        deal(USDC, address(oneD), initialAmount);

        bytes memory data = CalldataLib.encodeApprove(USDC, user);

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(IERC20All(USDC).allowance(address(oneD), user), type(uint256).max);

        vm.prank(user);
        IERC20All(USDC).transferFrom(address(oneD), user, initialAmount);
        assertEq(IERC20All(USDC).balanceOf(user), initialAmount);
    }
}
