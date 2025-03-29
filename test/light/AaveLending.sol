// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import "./utils/CalldataLib.sol";

contract AaveLightTest is BaseTest {
    OneDeltaComposerLight oneDV2;

    address internal USDC;
    address internal AAVE_V3_POOL;

    string internal lender;

    uint256 internal constant forkBlock = 26696865;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
        lender = Lenders.AAVE_V3;
        USDC = chain.getTokenAddress(Tokens.USDC);
        AAVE_V3_POOL = chain.getLendingController(lender);

        oneDV2 = new OneDeltaComposerLight(address(0));
    }

    function test_light_aave_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = AAVE_V3_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        // Get collateral balance before deposit
        uint256 collateralBefore = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeAaveDeposit(token, false, amount, user, pool);

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

    function test_light_aave_borrow() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = AAVE_V3_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);

        approveBorrowDelegation(user, token, address(oneDV2), lender);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeAaveBorrow(token, false, amountToBorrow, user, 2, pool);

        // Check balances before borrowing
        uint256 borrowBalanceBefore = chain.getDebtBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        // Check balances after borrowing
        uint256 borrowBalanceAfter = chain.getDebtBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert debt increased by borrowed amount
        assertApproxEqAbs(borrowBalanceAfter - borrowBalanceBefore, amountToBorrow, 0);
        // Assert underlying increased by borrowed amount
        assertApproxEqAbs(underlyingAfter - underlyingBefore, amountToBorrow, 0);
    }

    function test_light_aave_withdraw() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = AAVE_V3_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);

        address aToken = _getCollateralToken(token);

        approveWithdrawalDelegation(user, token, address(oneDV2), lender);

        uint256 amountToWithdraw = 10.0e6;
        bytes memory d = CalldataLib.encodeAaveWithdraw(token, false, amountToWithdraw, user, aToken, pool);

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

    function test_light_aave_repay() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = AAVE_V3_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);

        uint256 amountToBorrow = 10.0e6;
        borrowFromAave(token, user, amountToBorrow, pool);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 7.0e6;

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        address vToken = _getDebtToken(token);

        bytes memory d = CalldataLib.encodeAaveRepay(token, false, amountToRepay, user, 2, vToken, pool);

        // Check balances before repay
        uint256 debtBefore = chain.getDebtBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        // Check balances after repay
        uint256 debtAfter = chain.getDebtBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, 1);
        // Assert underlying decreased by repaid amount
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amountToRepay, 1);
    }

    function depositToAave(address token, address userAddress, uint256 amount, address pool) internal {
        deal(token, userAddress, 1000.0e6);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeAaveDeposit(token, false, amount, userAddress, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromAave(address token, address userAddress, uint256 amountToBorrow, address pool) internal {
        address vToken = _getDebtToken(token);

        vm.prank(userAddress);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        bytes memory d = CalldataLib.encodeAaveBorrow(token, false, amountToBorrow, userAddress, 2, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }

    function _getDebtToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).debt;
    }

    function _getCollateralToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).collateral;
    }
}
