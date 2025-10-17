// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

contract CompoundV2ComposerLightTest is BaseTest {
    uint16 internal constant COMPOUND_V2_ID = 3000;

    IComposerLike oneDV2;

    address internal USDC;
    address internal WETH;
    address internal VENUS_COMPTROLLER;
    string internal lender;

    uint256 internal constant forkBlock = 290934482;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ARBITRUM_ONE;

        _init(chainName, forkBlock, true);
        lender = Lenders.VENUS;
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        VENUS_COMPTROLLER = chain.getLendingController(lender);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function test_light_lending_compoundV2_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        address cToken = _getCollateralToken(token);

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

        bytes memory d = CalldataLib.encodeCompoundV2Deposit(token, amount, user, cToken, false);

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

    function test_light_lending_compoundV2_borrow() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;

        address cToken = _getCollateralToken(token);
        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV2(depositToken, user, amount, comptroller, false);

        approveBorrowDelegation(user, token, address(oneDV2), lender);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeCompoundV2Borrow(token, amountToBorrow, user, cToken);

        // Check balances before borrowing
        uint256 borrowBalanceBefore = chain.getDebtBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        // Check balances after borrowing
        uint256 borrowBalanceAfter = chain.getDebtBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert debt increased by borrowed amount
        assertApproxEqAbs(borrowBalanceAfter - borrowBalanceBefore, amountToBorrow, 1);
        // Assert underlying increased by borrowed amount
        assertApproxEqAbs(underlyingAfter - underlyingBefore, amountToBorrow, 1);
    }

    function test_light_lending_compoundV2_withdraw() external {
        vm.assume(user != address(0));

        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        depositToCompoundV2(token, user, amount, comptroller, false);

        address cToken = _getCollateralToken(token);

        approveWithdrawalDelegation(user, token, address(oneDV2), lender);

        uint256 amountToWithdraw = 10.0e6;
        bytes memory d = CalldataLib.encodeCompoundV2Withdraw(token, amountToWithdraw, user, cToken);

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

    function test_light_lending_compoundV2_repay() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;

        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV2(depositToken, user, amount, comptroller, false);

        uint256 amountToBorrow = 10.0e6;
        borrowFromCompoundV2(token, user, amountToBorrow, comptroller);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 7.0e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Repay(token, amountToRepay, user, cToken);

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

    function test_light_lending_compoundV2_repay_max() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;

        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV2(depositToken, user, amount, comptroller, false);

        uint256 amountToBorrow = 10.0e6;
        borrowFromCompoundV2(token, user, amountToBorrow, comptroller);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 11.0e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        bytes memory sweep = CalldataLib.encodeSweep(token, user, 0, SweepType.VALIDATE);
        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Repay(token, type(uint112).max, user, cToken);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d, sweep));

        assertApproxEqAbs(IERC20All(token).balanceOf(address(oneDV2)), 0, 0);
        assertApproxEqAbs(IERC20All(depositToken).balanceOf(address(oneDV2)), 0, 0);

        // Check balances after repay
        uint256 debtAfter = chain.getDebtBalance(user, token, lender);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(debtAfter, 0, 0);
    }

    /**
     * repay maximum but do not hold enough in the contract
     */
    function test_light_lending_compoundV2_repay_try_max() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;

        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV2(depositToken, user, amount, comptroller, false);

        uint256 amountToBorrow = 10.0e6;
        borrowFromCompoundV2(token, user, amountToBorrow, comptroller);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 9.0e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        bytes memory sweep = CalldataLib.encodeSweep(token, user, 0, SweepType.VALIDATE);
        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Repay(token, type(uint112).max, user, cToken);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d, sweep));

        assertApproxEqAbs(IERC20All(token).balanceOf(address(oneDV2)), 0, 0);
        assertApproxEqAbs(IERC20All(depositToken).balanceOf(address(oneDV2)), 0, 0);

        // Check balances after repay
        uint256 debtAfter = chain.getDebtBalance(user, token, lender);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(debtAfter, 1.0e6, 0);
    }

    function depositToCompoundV2(address token, address userAddress, uint256 amount, address comptroller, bool useMint) internal {
        deal(token, userAddress, amount);

        address[] memory cTokens = new address[](1);
        cTokens[0] = _getCollateralToken(token);

        vm.prank(userAddress);
        IERC20All(comptroller).enterMarkets(cTokens);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Deposit(token, amount, userAddress, cToken, useMint);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromCompoundV2(address token, address userAddress, uint256 amountToBorrow, address comptroller) internal {
        vm.prank(userAddress);
        IERC20All(comptroller).updateDelegate(address(oneDV2), true);

        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Borrow(token, amountToBorrow, userAddress, cToken);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }

    function _getCollateralToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).collateral;
    }
}
