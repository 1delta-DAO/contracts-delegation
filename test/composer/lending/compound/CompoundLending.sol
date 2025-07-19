// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

// solhint-disable max-line-length

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, encodeErc4646Deposit, encodeErc4646Withdraw
 */
contract CompoundV3ComposerLightTest is BaseTest {
    uint16 internal constant COMPOUND_V3_ID = 2000;

    IComposerLike oneDV2;

    address internal USDC;
    address internal COMPOUND_V3_USDC_COMET;
    address internal WETH;
    string internal lender;

    uint256 internal constant forkBlock = 26696865;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);
        lender = Lenders.COMPOUND_V3_USDC;
        USDC = chain.getTokenAddress(Tokens.USDC);
        vm.label(USDC, "USDC");
        COMPOUND_V3_USDC_COMET = chain.getLendingController(lender);
        vm.label(COMPOUND_V3_USDC_COMET, "comet");
        WETH = chain.getTokenAddress(Tokens.WETH);
        vm.label(WETH, "WETH");
        oneDV2 = ComposerPlugin.getComposer(chainName);
        vm.label(address(oneDV2), "composer");
    }

    function test_light_lending_compoundV3_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        // Get balances before deposit
        uint256 collateralBefore = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeCompoundV3Deposit(token, amount, user, comet);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        // Get balances after deposit
        uint256 collateralAfter = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert collateral balance increased by amount
        assertApproxEqAbs(collateralAfter - collateralBefore, amount, 1);
        // Assert underlying balance decreased by amount
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amount, 1);
    }

    function test_light_lending_compoundV3_borrow() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;

        uint256 depositAmount = 1.0e18;
        deal(depositToken, user, depositAmount);

        depositToCompoundV3(depositToken, user, depositAmount, comet);

        approveBorrowDelegation(user, depositToken, address(oneDV2), lender);

        uint256 amountToBorrow = 100.0e6;
        bytes memory d = CalldataLib.encodeCompoundV3Borrow(token, amountToBorrow, user, comet);

        // Check balances before borrowing
        uint256 borrowBalanceBefore = chain.getDebtBalance(user, token, lender);
        uint256 tokenBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        // Check balances after borrowing
        uint256 borrowBalanceAfter = chain.getDebtBalance(user, token, lender);
        uint256 tokenAfter = IERC20All(token).balanceOf(user);
        // Assert debt increased by borrowed amount
        assertApproxEqAbs(borrowBalanceAfter - borrowBalanceBefore, amountToBorrow, 1, "1");
        // Assert token balance increased by borrowed amount
        assertApproxEqAbs(tokenAfter - tokenBefore, amountToBorrow, 1, "3");
    }

    function test_light_lending_compoundV3_withdraw() external {
        vm.assume(user != address(0));

        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        depositToCompoundV3(token, user, amount, comet);

        approveWithdrawalDelegation(user, token, address(oneDV2), lender);

        uint256 amountToWithdraw = 10.0e6;
        bool isBaseToken = token == chain.getCometToBase(lender);
        bytes memory d = CalldataLib.encodeCompoundV3Withdraw(token, amountToWithdraw, user, comet, isBaseToken);

        // Check balances before withdrawal
        uint256 collateralBefore = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        // Check balances after withdrawal
        uint256 collateralAfter = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert collateral decreased by withdrawn amount
        assertApproxEqAbs(collateralBefore - collateralAfter, amountToWithdraw, 1);
        // Assert underlying increased by withdrawn amount
        assertApproxEqAbs(underlyingAfter - underlyingBefore, amountToWithdraw, 1);
    }

    function test_light_lending_compoundV3_repay() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;

        uint256 depositAmount = 1.0e18;
        deal(depositToken, user, depositAmount);

        depositToCompoundV3(depositToken, user, depositAmount, comet);

        uint256 amountToBorrow = 100.0e6;
        borrowFromCompoundV3(token, user, amountToBorrow, comet);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 70.0e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        bytes memory d = CalldataLib.encodeCompoundV3Repay(token, amountToRepay, user, comet);

        // Check balances before repay
        uint256 debtBefore = chain.getDebtBalance(user, token, lender);
        uint256 tokenBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        // Check balances after repay
        uint256 debtAfter = chain.getDebtBalance(user, token, lender);
        uint256 tokenAfter = IERC20All(token).balanceOf(user);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, 1, "1");
        // Assert token balance decreased by repaid amount
        assertApproxEqAbs(tokenBefore - tokenAfter, amountToRepay, 1, "3");
    }

    function test_light_lending_compoundV3_repay_max() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;

        uint256 depositAmount = 1.0e18;
        deal(depositToken, user, depositAmount);
        deal(token, user, depositAmount);

        depositToCompoundV3(depositToken, user, depositAmount, comet);

        uint256 amountToBorrow = 100.0e6;
        borrowFromCompoundV3(token, user, amountToBorrow, comet);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 101.0e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        bytes memory d = CalldataLib.encodeCompoundV3Repay(token, type(uint112).max, user, comet);

        bytes memory sweep = CalldataLib.encodeSweep(token, user, 0, SweepType.VALIDATE);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d, sweep));

        // Check balances after repay
        uint256 debtAfter = chain.getDebtBalance(user, token, lender);

        assertApproxEqAbs(IERC20All(token).balanceOf(address(oneDV2)), 0, 0);
        assertApproxEqAbs(IERC20All(depositToken).balanceOf(address(oneDV2)), 0, 0);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(debtAfter, 0, 0, "0");
    }

    function test_light_lending_compoundV3_try_repay_max() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;

        uint256 depositAmount = 1.0e18;
        deal(depositToken, user, depositAmount);

        depositToCompoundV3(depositToken, user, depositAmount, comet);

        uint256 amountToBorrow = 100.0e6;
        borrowFromCompoundV3(token, user, amountToBorrow, comet);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 90.0e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        bytes memory d = CalldataLib.encodeCompoundV3Repay(token, type(uint112).max, user, comet);

        bytes memory sweep = CalldataLib.encodeSweep(token, user, 0, SweepType.VALIDATE);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d, sweep));

        assertApproxEqAbs(IERC20All(token).balanceOf(address(oneDV2)), 0, 0);
        assertApproxEqAbs(IERC20All(depositToken).balanceOf(address(oneDV2)), 0, 0);
        // Check balances after repay
        uint256 debtAfter = chain.getDebtBalance(user, token, lender);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(debtAfter, 10.0e6, 0, "0");
    }

    function test_light_lending_compoundV3_full_compose() external {
        uint256 collateralAmount = 1.0e18;
        uint256 borrowAmount = 500.0e6;
        uint256 repayAmount = 200.0e6;
        uint256 withdrawAmount = 0.3e18;

        deal(WETH, user, collateralAmount);
        deal(USDC, user, repayAmount);

        vm.startPrank(user);
        // approve composer
        IERC20All(WETH).approve(address(oneDV2), type(uint256).max);
        IERC20All(USDC).approve(address(oneDV2), type(uint256).max);
        IERC20All(COMPOUND_V3_USDC_COMET).allow(address(oneDV2), true);
        // call composer
        oneDV2.deltaCompose(_createComposedCalldata(collateralAmount, borrowAmount, repayAmount, withdrawAmount));
        vm.stopPrank();
    }

    function _createComposedCalldata(
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 repayAmount,
        uint256 withdrawAmount
    )
        internal
        returns (bytes memory composedCalldata)
    {
        // approve comet
        composedCalldata =
            abi.encodePacked(CalldataLib.encodeApprove(WETH, COMPOUND_V3_USDC_COMET), CalldataLib.encodeApprove(USDC, COMPOUND_V3_USDC_COMET));
        // transfer collateral to composer
        composedCalldata = abi.encodePacked(composedCalldata, CalldataLib.encodeTransferIn(WETH, address(oneDV2), collateralAmount));
        // deposit collateral
        composedCalldata =
            abi.encodePacked(composedCalldata, CalldataLib.encodeCompoundV3Deposit(WETH, collateralAmount, user, COMPOUND_V3_USDC_COMET));
        // borrow
        composedCalldata = abi.encodePacked(composedCalldata, CalldataLib.encodeCompoundV3Borrow(USDC, borrowAmount, user, COMPOUND_V3_USDC_COMET));
        // transfer repay amount to composer
        composedCalldata = abi.encodePacked(composedCalldata, CalldataLib.encodeTransferIn(USDC, address(oneDV2), repayAmount));
        // repay
        composedCalldata = abi.encodePacked(composedCalldata, CalldataLib.encodeCompoundV3Repay(USDC, repayAmount, user, COMPOUND_V3_USDC_COMET));
        // withdraw to composer
        composedCalldata = abi.encodePacked(
            composedCalldata,
            CalldataLib.encodeCompoundV3Withdraw(WETH, withdrawAmount, address(oneDV2), COMPOUND_V3_USDC_COMET, WETH == chain.getCometToBase(lender))
        );
        // sweep to receiver
        composedCalldata = abi.encodePacked(composedCalldata, CalldataLib.encodeSweep(WETH, user, 0, SweepType.VALIDATE));
    }

    function depositToCompoundV3(address token, address userAddress, uint256 amount, address comet) internal {
        deal(token, userAddress, amount);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeCompoundV3Deposit(token, amount, userAddress, comet);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromCompoundV3(address token, address userAddress, uint256 amountToBorrow, address comet) internal {
        vm.prank(userAddress);
        IERC20All(comet).allow(address(oneDV2), true);

        bytes memory d = CalldataLib.encodeCompoundV3Borrow(token, amountToBorrow, userAddress, comet);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }
}
