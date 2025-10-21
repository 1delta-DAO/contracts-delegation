// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import "test/shared/chains/ChainInitializer.sol";
import "test/shared/chains/ChainFactory.sol";

/**
 * merged interface for simplicity
 */
interface ISilo {
    function switchCollateralToThisSilo() external;
    function setReceiveApproval(address owner, uint256 _amount) external;
    function convertToShares(uint256 _amount) external view returns (uint256);
    function convertToAssets(uint256 _amount) external view returns (uint256);
    function convertToShares(uint256 _amount, uint256 assetType) external view returns (uint256);
    function convertToAssets(uint256 _amount, uint256 assetType) external view returns (uint256);
    function debtBalanceOfUnderlying(address _silo, address _user) external view returns (uint256);
    function collateralBalanceOfUnderlying(address _silo, address _user) external view returns (uint256);
}

/**
 * Silo V2 basics:
 * Each silo is like an ERC4626 vault, except that a silo has separate tokens denominating the shares (a debt and collateral token)
 * Two silos are connected via a config that defines the params (ltv etc.) - this defines a conventional
 * lending market.
 * In a market, both assets can be borrowable.
 * Collateral enabled via deposit param (CollateralMode, see CalldataLib) - happens automatically.
 * A lens contract is used to read balances (as this seems quiute annoying otherwise).
 * Permissioning:
 *      Withdrawals: call `callateralSilo.approve(target, shares)`
 *      Borrows:     call `debtshareToken.setReceiveApproval(target, shares)`
 */
contract SiloV2ComposerLightTest is BaseTest {
    IComposerLike oneDV2;

    address internal WEETH;
    address internal WETH;
    address internal SILO_LENS = 0xF0B0218153633e6154c201d5A5d81128B0539336;
    address internal SILO_WEETH = 0x038722A3b78A10816Ae0EDC6afA768B03048a0cC;
    address internal SILO_WEETH_COLLATERAL_SHARE = 0xc8A7491Bc887d4f19bA7fa9dBf19ECfE2bFb4e3a;
    address internal SILO_WETH_DEBT_SHARE = 0x4155f07B12f35db4264cCe0257e8Bc0912C8Fc32;
    address internal SILO_WETH = 0x3613d1789583C790D30F3c6c7786A4f36f81C6eC;

    uint256 internal constant forkBlock = 391289621;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ARBITRUM_ONE;

        _init(chainName, forkBlock, true);
        WEETH = chain.getTokenAddress(Tokens.WEETH);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function test_light_lending_siloV2_deposit() external {
        vm.assume(user != address(0));

        address siloCollateralShare = SILO_WEETH_COLLATERAL_SHARE;
        address token = WEETH;
        uint256 amount = 1.0e18;
        deal(token, user, amount);

        address silo = SILO_WEETH;

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        // Get balances before deposit
        uint256 collateralBefore = _getAssetBalance(silo, user);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeSiloV2Deposit(token, amount, user, silo, uint8(0));

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        // Get balances after deposit
        uint256 collateralAfter = _getAssetBalance(silo, user);

        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert collateral balance increased by amount
        assertApproxEqAbs(collateralAfter - collateralBefore, amount, 1);
        // Assert underlying balance decreased by amount
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amount, 1);
    }

    function test_light_lending_siloV2_borrow() external {
        vm.assume(user != address(0));

        address depositToken = WEETH;
        address token = WETH;
        address collateralSilo = SILO_WEETH;
        address borrowSilo = SILO_WETH;
        address debtShareToken = SILO_WETH_DEBT_SHARE;

        uint256 amount = 1.0e18;

        depositToSiloV2(depositToken, user, amount, collateralSilo, uint8(SiloV2CollateralType.COLLATERAL));

        vm.prank(user);
        ISilo(debtShareToken).setReceiveApproval(address(oneDV2), type(uint256).max);

        uint256 amountToBorrow = 0.5e18;
        bytes memory composerCall = CalldataLib.encodeSiloV2Borrow(amountToBorrow, user, borrowSilo);

        // Check balances before borrowing
        uint256 borrowBalanceBefore = _getDebtBalance(borrowSilo, user);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(composerCall);

        // Check balances after borrowing
        uint256 borrowBalanceAfter = _getDebtBalance(borrowSilo, user);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert debt increased by borrowed amount
        assertApproxEqAbs(borrowBalanceAfter - borrowBalanceBefore, amountToBorrow, 1);
        // Assert underlying increased by borrowed amount
        assertApproxEqAbs(underlyingAfter - underlyingBefore, amountToBorrow, 0);
    }

    function test_light_lending_siloV2_withdraw() external {
        vm.assume(user != address(0));

        address depositToken = WEETH;
        address collateralSilo = SILO_WEETH;
        address collateralShareToken = SILO_WEETH;

        uint256 amount = 1.0e18;

        depositToSiloV2(depositToken, user, amount, collateralSilo, uint8(SiloV2CollateralType.COLLATERAL));

        vm.prank(user);
        IERC20All(collateralShareToken).approve(address(oneDV2), type(uint256).max);

        uint256 amountToWithdraw = 0.5e18;
        bytes memory d = CalldataLib.encodeSiloV2Withdraw(amountToWithdraw, user, collateralSilo, uint8(SiloV2CollateralType.COLLATERAL));

        // Check balances before withdrawal
        uint256 collateralBefore = _getAssetBalance(collateralSilo, user);
        uint256 underlyingBefore = IERC20All(depositToken).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        // Check balances after withdrawal
        uint256 collateralAfter = _getAssetBalance(collateralSilo, user);
        uint256 underlyingAfter = IERC20All(depositToken).balanceOf(user);

        // Assert collateral decreased by withdrawn amount
        assertApproxEqAbs(collateralBefore - collateralAfter, amountToWithdraw, 1);
        // Assert underlying increased by withdrawn amount
        assertApproxEqAbs(underlyingAfter - underlyingBefore, amountToWithdraw, 1);
    }

    function test_light_lending_siloV2_withdraw_all() external {
        vm.assume(user != address(0));

        address depositToken = WEETH;
        address collateralSilo = SILO_WEETH;
        address collateralShareToken = SILO_WEETH;

        uint256 amount = 1.0e18;

        depositToSiloV2(depositToken, user, amount, collateralSilo, uint8(SiloV2CollateralType.COLLATERAL));

        vm.prank(user);
        IERC20All(collateralShareToken).approve(address(oneDV2), type(uint256).max);

        uint256 amountToWithdraw = type(uint112).max;
        bytes memory d = CalldataLib.encodeSiloV2Withdraw(amountToWithdraw, user, collateralSilo, uint8(SiloV2CollateralType.COLLATERAL));

        // Check balances before withdrawal
        uint256 collateralBefore = _getAssetBalance(collateralSilo, user);
        uint256 underlyingBefore = IERC20All(depositToken).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        // Check balances after withdrawal
        uint256 collateralAfter = _getAssetBalance(collateralSilo, user);
        uint256 underlyingAfter = IERC20All(depositToken).balanceOf(user);

        // Assert collateral decreased by withdrawn amount
        assertApproxEqAbs(collateralAfter, 0, 0);
        // Assert underlying increased by withdrawn amount
        assertApproxEqAbs(underlyingAfter - underlyingBefore, collateralBefore, 1);
    }

    function test_light_lending_siloV2_repay() external {
        vm.assume(user != address(0));

        address depositToken = WEETH;
        address token = WETH;
        address collateralSilo = SILO_WEETH;
        address borrowSilo = SILO_WETH;
        address debtShareToken = SILO_WETH_DEBT_SHARE;

        uint256 amount = 1.0e18;

        depositToSiloV2(depositToken, user, amount, collateralSilo, uint8(SiloV2CollateralType.COLLATERAL));

        vm.prank(user);
        ISilo(debtShareToken).setReceiveApproval(address(oneDV2), type(uint256).max);

        uint256 amountToBorrow = 0.5e18;
        bytes memory composerCall = CalldataLib.encodeSiloV2Borrow(amountToBorrow, user, borrowSilo);

        vm.prank(user);
        oneDV2.deltaCompose(composerCall);

        uint256 amountToRepay = 0.25e18;
        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), amountToRepay);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        composerCall = CalldataLib.encodeSiloV2Repay(token, amountToRepay, user, borrowSilo);

        // Check balances before repay
        uint256 borrowBalanceBefore = _getDebtBalance(borrowSilo, user);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, composerCall));

        uint256 borrowBalanceAfter = _getDebtBalance(borrowSilo, user);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(borrowBalanceBefore - borrowBalanceAfter, amountToRepay, 1);
        // Assert underlying decreased by repaid amount
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amountToRepay, 1);
    }

    function test_light_lending_siloV2_repay_all() external {
        vm.assume(user != address(0));

        address depositToken = WEETH;
        address token = WETH;
        address collateralSilo = SILO_WEETH;
        address borrowSilo = SILO_WETH;
        address debtShareToken = SILO_WETH_DEBT_SHARE;

        uint256 amount = 1.0e18;

        depositToSiloV2(depositToken, user, amount, collateralSilo, uint8(SiloV2CollateralType.COLLATERAL));

        vm.prank(user);
        ISilo(debtShareToken).setReceiveApproval(address(oneDV2), type(uint256).max);

        uint256 amountToBorrow = 0.5e18;
        bytes memory composerCall = CalldataLib.encodeSiloV2Borrow(amountToBorrow, user, borrowSilo);

        vm.prank(user);
        oneDV2.deltaCompose(composerCall);

        deal(token, user, 2.0e18);

        uint256 amountToRepay = 2.0e18;
        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), amountToRepay);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        composerCall = CalldataLib.encodeSiloV2Repay(token, type(uint112).max, user, borrowSilo);

        // Check balances before repay
        uint256 borrowBalanceBefore = _getDebtBalance(borrowSilo, user);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, composerCall, CalldataLib.encodeSweep(token, user, 0, SweepType.VALIDATE)));

        uint256 borrowBalanceAfter = _getDebtBalance(borrowSilo, user);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(borrowBalanceAfter, 0, 0);
        // Assert underlying decreased by repaid amount
        assertApproxEqAbs(underlyingBefore - underlyingAfter, borrowBalanceBefore, 1);
    }

    function test_light_lending_siloV2_repay_max_borrow_balance_less_than_contract_balance() external {
        address depositToken = WEETH;
        address token = WETH;
        address collateralSilo = SILO_WEETH;
        address borrowSilo = SILO_WETH;
        address debtShareToken = SILO_WETH_DEBT_SHARE;

        uint256 amount = 1.0e18;

        depositToSiloV2(depositToken, user, amount, collateralSilo, uint8(SiloV2CollateralType.COLLATERAL));

        vm.prank(user);
        ISilo(debtShareToken).setReceiveApproval(address(oneDV2), type(uint256).max);

        uint256 amountToBorrow = 0.3e18;
        bytes memory composerCall = CalldataLib.encodeSiloV2Borrow(amountToBorrow, user, borrowSilo);

        vm.prank(user);
        oneDV2.deltaCompose(composerCall);

        deal(token, address(oneDV2), 1.0e18);
        deal(token, user, 0.1e18);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), 0.1e18);

        bytes memory transferTo = CalldataLib.encodeTransferIn(token, address(oneDV2), 0.1e18);

        composerCall = CalldataLib.encodeSiloV2Repay(token, type(uint112).max, user, borrowSilo);

        uint256 borrowBalanceBefore = _getDebtBalance(borrowSilo, user);
        uint256 underlyingBefore = IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, composerCall));

        uint256 borrowBalanceAfter = _getDebtBalance(borrowSilo, user);
        uint256 underlyingAfter = IERC20All(token).balanceOf(user);

        assertApproxEqAbs(borrowBalanceAfter, 0, 0);
        assertApproxEqAbs(borrowBalanceBefore - borrowBalanceAfter, amountToBorrow, 1);
        assertApproxEqAbs(underlyingBefore - underlyingAfter, 0.1e18, 1);
    }

    function depositToSiloV2(address token, address userAddress, uint256 amount, address silo, uint8 collateralMode) internal {
        deal(token, userAddress, amount);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeSiloV2Deposit(token, amount, userAddress, silo, collateralMode);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function _getAssetBalance(address silo, address userAddress) internal view returns (uint256) {
        return ISilo(SILO_LENS).collateralBalanceOfUnderlying(silo, userAddress);
    }

    function _getDebtBalance(address silo, address userAddress) internal view returns (uint256) {
        return ISilo(SILO_LENS).debtBalanceOfUnderlying(silo, userAddress);
    }
}
