// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {OneDeltaComposerLight} from "light/Composer.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/light/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

/**
 * Special Aave V3s that have no mode (e.g. YLDR)
 */
contract AaveV3NoModesLightTest is BaseTest {
    IComposerLike oneDV2;
    address internal LBTC;
    address internal USDC;
    address internal POOL;
    string internal lender;

    uint256 internal constant forkBlock = 26696865;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock);
        lender = Lenders.YLDR;
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        POOL = chain.getLendingController(lender);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function test_light_lending_yldr_borrow() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);
        approveBorrowDelegation(user, token, address(oneDV2), lender);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeAaveBorrow(token, false, amountToBorrow, user, 0, pool);

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

    function test_light_lending_yldr_repay() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = POOL;
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

        bytes memory d = CalldataLib.encodeAaveRepay(token, false, amountToRepay, user, 0, vToken, pool);

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

        bytes memory d = CalldataLib.encodeAaveBorrow(token, false, amountToBorrow, userAddress, 0, pool);

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
