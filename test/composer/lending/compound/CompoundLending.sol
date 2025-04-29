// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

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

        _init(chainName, forkBlock);
        lender = Lenders.COMPOUND_V3_USDC;
        USDC = chain.getTokenAddress(Tokens.USDC);
        COMPOUND_V3_USDC_COMET = chain.getLendingController(lender);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = ComposerPlugin.getComposer(chainName);
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
        uint256 borrowBalanceBefore = chain.getDebtBalance(user, depositToken, lender);
        uint256 tokenBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        // Check balances after borrowing
        uint256 borrowBalanceAfter = chain.getDebtBalance(user, depositToken, lender);
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
        bytes memory d = CalldataLib.encodeCompoundV3Withdraw(token, amountToWithdraw, user, comet, token == chain.getCometToBase(lender));

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
        uint256 debtBefore = chain.getDebtBalance(user, depositToken, lender);
        uint256 tokenBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        // Check balances after repay
        uint256 debtAfter = chain.getDebtBalance(user, depositToken, lender);
        uint256 tokenAfter = IERC20All(token).balanceOf(user);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, 1, "1");
        // Assert token balance decreased by repaid amount
        assertApproxEqAbs(tokenBefore - tokenAfter, amountToRepay, 1, "3");
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
