// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";
import {StdStyle as S} from "forge-std/StdStyle.sol";
import {MorphoMathLib} from "test/composer/lending/utils/MathLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "test/shared/composers/ComposerPlugin.sol";
import {MockERC20Revert} from "test/mocks/MockERC20Revert.sol";
import {MockERC20NoReturn} from "test/mocks/MockERC20NoReturn.sol";
import {MockReceiver} from "test/mocks/MockReceiver.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {WETH9} from "test/mocks/WETH9.sol";

contract TransfersTest is BaseTest, DeltaErrors {
    IComposerLike oneD;

    address internal WETH;
    address internal USDC;

    function setUp() public virtual {
        user = address(0x1de17a);
        vm.deal(user, 100 ether);
        vm.label(user, "user");

        MockERC20 mockUSDC = new MockERC20("USD Coin", "USDC", 6);
        USDC = address(mockUSDC);

        WETH9 mockWETH = new WETH9();
        WETH = address(mockWETH);

        oneD = ComposerPlugin.getComposer(Chains.BASE);
    }

    // ------------------------------------------------------------------------
    // sweep tests
    // ------------------------------------------------------------------------

    function test_unit_transfer_token_sweep_token_amount() external {
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

    function test_unit_transfer_token_sweep_validate() external {
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

    function test_unit_transfer_token_sweep_validate_reverts() external {
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

    function test_unit_transfer_token_sweep_balance() external {
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

    function test_unit_transfer_token_sweep_native_balance() external {
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

    function test_unit_transfer_token_sweep_native_amount() external {
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

    function test_unit_transfer_token_sweep_native_amount_reverts_amount_mode() external {
        uint256 initialAmount = 1 ether;
        uint256 sweepAmount = 5 ether;
        vm.deal(address(oneD), initialAmount);

        bytes memory data = CalldataLib.encodeSweep(address(0), user, sweepAmount, SweepType.AMOUNT);

        vm.expectRevert(NATIVE_TRANSFER);
        vm.prank(user);
        oneD.deltaCompose(data);
    }

    function test_unit_transfer_token_sweep_native_amount_reverts_validate_mode() external {
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

    function test_unit_transfer_token_transferIn_zero() external {
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

    function test_unit_transfer_token_transferIn_specific() external {
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

    function test_unit_transfer_native_wrapUnwrap() external {
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

    function test_unit_transfer_token_approve_basic() external {
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

    function test_unit_transfer_unwrap_validate_insufficient_balance() external {
        uint256 initialAmount = 1 ether;
        vm.deal(address(oneD), initialAmount);

        bytes memory wrapData = CalldataLib.encodeWrap(initialAmount, WETH);
        vm.prank(user);
        oneD.deltaCompose(wrapData);

        uint256 minAmount = 2 ether;
        bytes memory unwrapData = CalldataLib.encodeUnwrap(WETH, user, minAmount, SweepType.VALIDATE);

        vm.prank(user);
        vm.expectRevert(SLIPPAGE);
        oneD.deltaCompose(unwrapData);
    }

    function test_unit_transfer_token_transferFrom_non_erc20_compliant() external {
        MockERC20NoReturn mockToken = new MockERC20NoReturn(1000e18);
        uint256 transferAmount = 500e18;
        mockToken.transfer(user, 1000e18);

        vm.prank(user);
        mockToken.approve(address(oneD), type(uint256).max);

        bytes memory data = CalldataLib.encodeTransferIn(address(mockToken), address(oneD), transferAmount);

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(mockToken.balanceOf(user), 1000e18 - transferAmount);
        assertEq(mockToken.balanceOf(address(oneD)), transferAmount);
    }

    function test_unit_transfer_token_transferFrom_reverts_on_failure() external {
        MockERC20Revert mockToken = new MockERC20Revert(1000e18);
        uint256 transferAmount = 500e18;
        mockToken.transfer(user, 1000e18);

        vm.prank(user);
        mockToken.approve(address(oneD), type(uint256).max);

        mockToken.setShouldRevertTransferFrom(true);

        bytes memory data = CalldataLib.encodeTransferIn(address(mockToken), address(oneD), transferAmount);

        vm.prank(user);
        vm.expectRevert("TransferFrom reverted");
        oneD.deltaCompose(data);
    }

    function test_unit_transfer_token_sweep_token_reverts_on_transfer() external {
        MockERC20Revert mockToken = new MockERC20Revert(1000e18);
        mockToken.transfer(address(oneD), 1000e18);
        mockToken.setShouldRevertTransfer(true);

        bytes memory data = CalldataLib.encodeSweep(address(mockToken), user, 500e18, SweepType.AMOUNT);

        vm.prank(user);
        vm.expectRevert("Transfer reverted");
        oneD.deltaCompose(data);
    }

    function test_unit_transfer_token_sweep_native_receiver_cannot_receive() external {
        uint256 initialAmount = 1 ether;
        vm.deal(address(oneD), initialAmount);

        MockReceiver receiver = new MockReceiver(false);

        bytes memory data = CalldataLib.encodeSweep(address(0), address(receiver), initialAmount, SweepType.AMOUNT);

        vm.prank(user);
        vm.expectRevert(NATIVE_TRANSFER);
        oneD.deltaCompose(data);
    }

    function test_unit_transfer_unwrap_receiver_cannot_receive_native() external {
        uint256 initialAmount = 1 ether;
        vm.deal(address(oneD), initialAmount);

        bytes memory wrapData = CalldataLib.encodeWrap(initialAmount, WETH);
        vm.prank(user);
        oneD.deltaCompose(wrapData);

        MockReceiver receiver = new MockReceiver(false);
        bytes memory unwrapData = CalldataLib.encodeUnwrap(WETH, address(receiver), initialAmount, SweepType.AMOUNT);

        vm.prank(user);
        vm.expectRevert(NATIVE_TRANSFER);
        oneD.deltaCompose(unwrapData);
    }
}
