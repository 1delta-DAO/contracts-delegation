// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import "test/shared/chains/ChainInitializer.sol";
import "test/shared/chains/ChainFactory.sol";

contract UnitusComposerLightTest is BaseTest {
    IComposerLike oneDV2;

    address internal USDC;
    address internal WETH;
    address internal UNITUS_COMPTROLLER;
    string internal lender;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        string memory chainName = Chains.ETHEREUM_MAINNET;

        _init(chainName, forkBlock, true);
        lender = Lenders.UNITUS;
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        UNITUS_COMPTROLLER = chain.getLendingController(lender);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    // ─── DEPOSIT ────────────────────────────────────────────────

    function test_integ_lending_unitus_deposit_erc20() external {
        vm.assume(user != address(0));

        address token = USDC;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        address cToken = _getCollateralToken(token);

        uint256 collateralBefore = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        bytes memory transferTo = CalldataLib.encodeTransferIn(token, address(oneDV2), amount);
        bytes memory d = CalldataLib.encodeCompoundV2Deposit(token, amount, user, cToken, uint8(CompoundV2Selector.MINT_ITOKEN));

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        uint256 collateralAfter = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        assertApproxEqAbs(collateralAfter - collateralBefore, amount, amount / 1e6);
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amount, 0);
    }

    function test_integ_lending_unitus_deposit_native() external {
        vm.assume(user != address(0));

        address token = address(0);
        uint256 amount = 1.0e18;
        deal(user, amount);

        address cToken = _getCollateralToken(token);

        uint256 collateralBefore = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingBefore = user.balance;

        // native deposit uses the compound-style mint() — selectorId irrelevant for native path
        bytes memory d = CalldataLib.encodeCompoundV2Deposit(token, amount, user, cToken, uint8(CompoundV2Selector.MINT_ITOKEN));

        vm.prank(user);
        oneDV2.deltaCompose{value: amount}(d);

        uint256 collateralAfter = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingAfter = user.balance;

        assertApproxEqAbs(collateralAfter - collateralBefore, amount, (amount * 9999) / 10000);
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amount, 0);
    }

    // ─── WITHDRAW ───────────────────────────────────────────────

    function test_integ_lending_unitus_withdraw_erc20() external {
        vm.assume(user != address(0));

        address token = USDC;
        uint256 amount = 100.0e6;

        depositToUnitus(token, user, amount);

        address cToken = _getCollateralToken(token);
        approveWithdrawalDelegation(user, token, address(oneDV2), lender);

        uint256 amountToWithdraw = 10.0e6;
        bytes memory d =
            CalldataLib.encodeCompoundV2Withdraw(token, amountToWithdraw, user, cToken, uint8(CompoundV2Selector.REDEEM_ITOKEN));

        uint256 collateralBefore = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        uint256 collateralAfter = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        assertApproxEqAbs(collateralBefore - collateralAfter, amountToWithdraw, amountToWithdraw / 1e6);
        assertApproxEqAbs(underlyingAfter - underlyingBefore, amountToWithdraw, amountToWithdraw / 1e6);
    }

    function test_integ_lending_unitus_withdraw_native() external {
        address token = address(0);
        uint256 amount = 1.0e18;

        depositNativeToUnitus(token, user, amount);

        address cToken = _getCollateralToken(token);

        // approve iToken spending for redeem(address,uint256)
        vm.prank(user);
        IERC20All(cToken).approve(address(oneDV2), type(uint256).max);

        uint256 amountToWithdraw = 0.1e18;
        bytes memory d =
            CalldataLib.encodeCompoundV2Withdraw(token, amountToWithdraw, user, cToken, uint8(CompoundV2Selector.REDEEM_ITOKEN));

        uint256 collateralBefore = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingBefore = user.balance;

        vm.prank(user);
        oneDV2.deltaCompose(d);

        uint256 collateralAfter = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingAfter = user.balance;

        assertApproxEqAbs(collateralBefore - collateralAfter, amountToWithdraw, (amountToWithdraw * 9999) / 10000);
        assertApproxEqAbs(underlyingAfter - underlyingBefore, amountToWithdraw, 0);
    }

    function test_integ_lending_unitus_withdraw_full_erc20() external {
        vm.assume(user != address(0));

        address token = USDC;
        uint256 amount = 100.0e6;

        depositToUnitus(token, user, amount);

        address cToken = _getCollateralToken(token);
        approveWithdrawalDelegation(user, token, address(oneDV2), lender);

        // withdraw max — composer clamps to cToken balance
        bytes memory d =
            CalldataLib.encodeCompoundV2Withdraw(token, type(uint112).max, user, cToken, uint8(CompoundV2Selector.REDEEM_ITOKEN));

        vm.prank(user);
        oneDV2.deltaCompose(d);

        // collateral should be ~0
        uint256 collateralAfter = chain.getCollateralBalance(user, token, lender);
        assertApproxEqAbs(collateralAfter, 0, 0);

        // no withdraw dust left in composer
        assertApproxEqAbs(IERC20All(token).balanceOf(address(oneDV2)), 0, 0);
        assertApproxEqAbs(IERC20All(cToken).balanceOf(address(oneDV2)), 0, 0);
    }

    // ─── REPAY ──────────────────────────────────────────────────

    function test_integ_lending_unitus_repay_max_erc20() external {
        vm.assume(user != address(0));

        address depositToken = address(0);
        address token = USDC;

        uint256 depositAmount = 10.0e18;
        depositNativeToUnitus(depositToken, user, depositAmount);

        // deal extra USDC before borrow (deal on USDC proxy is unreliable after borrow sets balance)
        uint256 extra = 1.0e6;
        deal(token, user, extra);

        uint256 amountToBorrow = 10.0e6;
        borrowFromUnitus(token, user, amountToBorrow);
        // user now has extra + amountToBorrow USDC

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        // overpay: transfer more than debt
        uint256 amountToTransfer = extra + amountToBorrow;

        bytes memory transferTo = CalldataLib.encodeTransferIn(token, address(oneDV2), amountToTransfer);
        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Repay(token, type(uint112).max, user, cToken);
        bytes memory sweep = CalldataLib.encodeSweep(token, user, 0, SweepType.VALIDATE);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d, sweep));

        // debt should be 0
        uint256 debtAfter = chain.getDebtBalance(user, token, lender);
        assertApproxEqAbs(debtAfter, 0, 0);

        // no dust left in composer
        assertApproxEqAbs(IERC20All(token).balanceOf(address(oneDV2)), 0, 0);
    }

    function test_integ_lending_unitus_repay_erc20() external {
        vm.assume(user != address(0));

        address depositToken = address(0); // deposit ETH as collateral
        address token = USDC;

        uint256 depositAmount = 10.0e18;
        depositNativeToUnitus(depositToken, user, depositAmount);

        uint256 amountToBorrow = 10.0e6;
        borrowFromUnitus(token, user, amountToBorrow);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 7.0e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(token, address(oneDV2), amountToRepay);
        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Repay(token, amountToRepay, user, cToken);

        uint256 debtBefore = chain.getDebtBalance(user, token, lender);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        uint256 debtAfter = chain.getDebtBalance(user, token, lender);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, amountToRepay / 1e6);
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amountToRepay, 0);
    }

    function test_integ_lending_unitus_repay_native() external {
        vm.assume(user != address(0));

        address depositToken = USDC;
        address token = address(0);

        uint256 depositAmount = 1000000.0e6;
        depositToUnitus(depositToken, user, depositAmount);

        uint256 amountToBorrow = 1.0e18;
        borrowFromUnitus(token, user, amountToBorrow);

        uint256 amountToRepay = 0.5e18;

        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Repay(token, amountToRepay, user, cToken);

        uint256 debtBefore = chain.getDebtBalance(user, token, lender);
        uint256 underlyingBefore = user.balance;

        vm.prank(user);
        oneDV2.deltaCompose{value: amountToRepay}(d);

        uint256 debtAfter = chain.getDebtBalance(user, token, lender);
        uint256 underlyingAfter = user.balance;

        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, amountToRepay / 1e6);
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amountToRepay, 0);
    }

    // ─── HELPERS ────────────────────────────────────────────────

    function depositToUnitus(address token, address userAddress, uint256 amount) internal {
        deal(token, userAddress, amount);

        address cToken = _getCollateralToken(token);
        address[] memory cTokens = new address[](1);
        cTokens[0] = cToken;

        vm.prank(userAddress);
        ILendingTools(UNITUS_COMPTROLLER).enterMarkets(cTokens);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.encodeTransferIn(token, address(oneDV2), amount);
        bytes memory d =
            CalldataLib.encodeCompoundV2Deposit(token, amount, userAddress, cToken, uint8(CompoundV2Selector.MINT_ITOKEN));

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function depositNativeToUnitus(address token, address userAddress, uint256 amount) internal {
        vm.deal(userAddress, amount);

        address cToken = _getCollateralToken(token);
        address[] memory cTokens = new address[](1);
        cTokens[0] = cToken;

        vm.prank(userAddress);
        ILendingTools(UNITUS_COMPTROLLER).enterMarkets(cTokens);

        bytes memory d =
            CalldataLib.encodeCompoundV2Deposit(token, amount, userAddress, cToken, uint8(CompoundV2Selector.MINT_ITOKEN));

        vm.prank(userAddress);
        oneDV2.deltaCompose{value: amount}(d);
    }

    function borrowFromUnitus(address token, address userAddress, uint256 amountToBorrow) internal {
        address cToken = _getCollateralToken(token);

        vm.prank(userAddress);
        UnitusBorrow(cToken).borrow(amountToBorrow);
    }

    function _getCollateralToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).collateral;
    }
}

interface UnitusBorrow {
    function borrow(uint256) external;
}
