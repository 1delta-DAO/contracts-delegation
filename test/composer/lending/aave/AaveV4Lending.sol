// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "test/shared/composers/ComposerPlugin.sol";

// Minimal Aave V4 interfaces for testing

interface IHub {
    function getAssetId(address underlying) external view returns (uint256);
}

interface ISpoke {
    function getReserveId(address hub, uint256 assetId) external view returns (uint256);
    function getReserveCount() external view returns (uint256);

    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);
    function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);

    function setUserPositionManager(address positionManager, bool approve) external;
    function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral, address onBehalfOf) external;
}

interface ITakerPositionManager {
    function approveWithdraw(address spoke, uint256 reserveId, address spender, uint256 amount) external;
    function approveBorrow(address spoke, uint256 reserveId, address spender, uint256 amount) external;
}

contract AaveV4LendingTest is BaseTest {
    IComposerLike oneDV2;

    // Aave V4 Ethereum mainnet addresses
    address constant CORE_HUB = 0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9;
    address constant MAIN_SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;

    // Position managers activated on Main Spoke at block 24727090
    address constant GIVER_PM = 0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e;
    address constant TAKER_PM = 0x6c044c0D3801499bCAbfAd458B70880bc518e9F7;

    address internal USDC;
    address internal WETH;

    ISpoke spoke = ISpoke(MAIN_SPOKE);
    IHub hub = IHub(CORE_HUB);

    uint256 usdcReserveId;
    uint256 wethReserveId;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        string memory chainName = Chains.ETHEREUM_MAINNET;

        _init(chainName, forkBlock, true);

        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = ComposerPlugin.getComposer(chainName);

        // Resolve reserve IDs dynamically
        uint256 usdcAssetId = hub.getAssetId(USDC);
        usdcReserveId = spoke.getReserveId(CORE_HUB, usdcAssetId);

        uint256 wethAssetId = hub.getAssetId(WETH);
        wethReserveId = spoke.getReserveId(CORE_HUB, wethAssetId);
    }

    // ═══════════════════════════════════════════════════
    // Deposit
    // ═══════════════════════════════════════════════════

    function test_v4_deposit_basic() external {
        deal(USDC, user, 1000e6);
        uint256 amount = 100e6;

        vm.prank(user);
        IERC20All(USDC).approve(address(oneDV2), type(uint256).max);

        // User must approve GiverPM as position manager on spoke
        vm.prank(user);
        spoke.setUserPositionManager(GIVER_PM, true);

        uint256 supplyBefore = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        bytes memory transferTo = CalldataLib.encodeTransferIn(USDC, address(oneDV2), amount);
        bytes memory d = CalldataLib.encodeAaveV4Deposit(USDC, amount, user, usdcReserveId, MAIN_SPOKE, GIVER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        uint256 supplyAfter = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(supplyAfter - supplyBefore, amount, 1);
        assertApproxEqAbs(balanceBefore - balanceAfter, amount, 1);
    }

    // ═══════════════════════════════════════════════════
    // Borrow
    // ═══════════════════════════════════════════════════

    function test_v4_borrow_basic() external {
        // Deposit WETH as collateral
        _depositViaComposer(WETH, user, 10 ether);
        _enableCollateral(wethReserveId, user);

        uint256 amountToBorrow = 100e6;

        // User must approve TakerPM and grant borrow allowance to the composer
        vm.prank(user);
        spoke.setUserPositionManager(TAKER_PM, true);
        vm.prank(user);
        ITakerPositionManager(TAKER_PM).approveBorrow(MAIN_SPOKE, usdcReserveId, address(oneDV2), type(uint256).max);

        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        bytes memory d = CalldataLib.encodeAaveV4Borrow(USDC, amountToBorrow, user, usdcReserveId, MAIN_SPOKE, TAKER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(debtAfter - debtBefore, amountToBorrow, 1);
        assertApproxEqAbs(balanceAfter - balanceBefore, amountToBorrow, 1);
    }

    // ═══════════════════════════════════════════════════
    // Withdraw
    // ═══════════════════════════════════════════════════

    function test_v4_withdraw_basic() external {
        _depositViaComposer(USDC, user, 1000e6);

        uint256 amountToWithdraw = 100e6;

        // User must approve TakerPM and grant withdraw allowance to the composer
        vm.prank(user);
        spoke.setUserPositionManager(TAKER_PM, true);
        vm.prank(user);
        ITakerPositionManager(TAKER_PM).approveWithdraw(MAIN_SPOKE, usdcReserveId, address(oneDV2), type(uint256).max);

        uint256 supplyBefore = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        bytes memory d = CalldataLib.encodeAaveV4Withdraw(USDC, amountToWithdraw, user, usdcReserveId, MAIN_SPOKE, TAKER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        uint256 supplyAfter = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(supplyBefore - supplyAfter, amountToWithdraw, 1);
        assertApproxEqAbs(balanceAfter - balanceBefore, amountToWithdraw, 1);
    }

    // ═══════════════════════════════════════════════════
    // Repay
    // ═══════════════════════════════════════════════════

    function test_v4_repay_basic() external {
        _depositViaComposer(WETH, user, 10 ether);
        _enableCollateral(wethReserveId, user);
        _borrowViaComposer(USDC, user, 100e6);

        vm.prank(user);
        IERC20All(USDC).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 50e6;

        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        bytes memory transferTo = CalldataLib.encodeTransferIn(USDC, address(oneDV2), amountToRepay);
        bytes memory d = CalldataLib.encodeAaveV4Repay(USDC, amountToRepay, user, usdcReserveId, MAIN_SPOKE, GIVER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, 1);
        assertApproxEqAbs(balanceBefore - balanceAfter, amountToRepay, 1);
    }

    // ═══════════════════════════════════════════════════
    // Max amount tests
    // ═══════════════════════════════════════════════════

    function test_v4_repay_tryMax() external {
        _depositViaComposer(WETH, user, 10 ether);
        _enableCollateral(wethReserveId, user);
        _borrowViaComposer(USDC, user, 100e6);

        vm.prank(user);
        IERC20All(USDC).approve(address(oneDV2), type(uint256).max);

        // Transfer less than debt
        uint256 amountToRepay = 50e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(USDC, address(oneDV2), amountToRepay);
        bytes memory d = CalldataLib.encodeAaveV4Repay(USDC, type(uint112).max, user, usdcReserveId, MAIN_SPOKE, GIVER_PM);
        bytes memory sweep = CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE);

        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d, sweep));

        // Composer should have no leftover
        assertApproxEqAbs(IERC20All(USDC).balanceOf(address(oneDV2)), 0, 0);

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, 1);
        assertApproxEqAbs(balanceBefore - balanceAfter, amountToRepay, 1);
    }

    function test_v4_withdraw_max() external {
        uint256 depositAmount = 500e6;
        _depositViaComposer(USDC, user, depositAmount);

        // User must approve TakerPM and grant withdraw allowance to the composer
        vm.prank(user);
        spoke.setUserPositionManager(TAKER_PM, true);
        vm.prank(user);
        ITakerPositionManager(TAKER_PM).approveWithdraw(MAIN_SPOKE, usdcReserveId, address(oneDV2), type(uint256).max);

        uint256 supplyBefore = spoke.getUserSuppliedAssets(usdcReserveId, user);

        bytes memory d = CalldataLib.encodeAaveV4Withdraw(USDC, type(uint112).max, user, usdcReserveId, MAIN_SPOKE, TAKER_PM);

        vm.prank(user);
        oneDV2.deltaCompose(d);

        uint256 supplyAfter = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertEq(supplyAfter, 0, "supply should be zero after max withdraw");
        assertApproxEqAbs(balanceAfter, depositAmount, 1);
    }

    // ═══════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════

    function _depositViaComposer(address token, address userAddr, uint256 amount) internal {
        deal(token, userAddr, amount);

        uint256 reserveId = _getReserveId(token);

        vm.startPrank(userAddr);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);
        spoke.setUserPositionManager(GIVER_PM, true);

        bytes memory transferTo = CalldataLib.encodeTransferIn(token, address(oneDV2), amount);
        bytes memory d = CalldataLib.encodeAaveV4Deposit(token, amount, userAddr, reserveId, MAIN_SPOKE, GIVER_PM);

        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
        vm.stopPrank();
    }

    function _borrowViaComposer(address token, address userAddr, uint256 amountToBorrow) internal {
        uint256 reserveId = _getReserveId(token);

        vm.startPrank(userAddr);
        spoke.setUserPositionManager(TAKER_PM, true);
        ITakerPositionManager(TAKER_PM).approveBorrow(MAIN_SPOKE, reserveId, address(oneDV2), type(uint256).max);

        bytes memory d = CalldataLib.encodeAaveV4Borrow(token, amountToBorrow, userAddr, reserveId, MAIN_SPOKE, TAKER_PM);
        oneDV2.deltaCompose(d);
        vm.stopPrank();
    }

    function _enableCollateral(uint256 reserveId, address userAddr) internal {
        vm.prank(userAddr);
        spoke.setUsingAsCollateral(reserveId, true, userAddr);
    }

    function _getReserveId(address token) internal view returns (uint256) {
        uint256 assetId = hub.getAssetId(token);
        return spoke.getReserveId(CORE_HUB, assetId);
    }
}
