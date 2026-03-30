// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";

// Minimal Aave V4 interfaces for testing

interface IHub {
    function getAssetId(address underlying) external view returns (uint256);
}

interface ISpoke {
    struct Reserve {
        address underlying;
        address hub;
        uint16 assetId;
        uint8 decimals;
        uint24 collateralRisk;
        bytes32 flags;
        uint32 dynamicConfigKey;
    }

    function getReserveId(address hub, uint256 assetId) external view returns (uint256);
    function getReserveCount() external view returns (uint256);
    function getReserve(uint256 reserveId) external view returns (Reserve memory);

    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);
    function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);
    function getUserReserveStatus(uint256 reserveId, address user) external view returns (bool isCollateral, bool isBorrowed);

    function setUserPositionManager(address positionManager, bool approve) external;
    function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral, address onBehalfOf) external;
    function isPositionManagerActive(address positionManager) external view returns (bool);
    function isPositionManager(address user, address positionManager) external view returns (bool);
}

interface IGiverPositionManager {
    function supplyOnBehalfOf(
        address spoke,
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf
    ) external returns (uint256, uint256);

    function repayOnBehalfOf(
        address spoke,
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf
    ) external returns (uint256, uint256);
}

interface ITakerPositionManager {
    function withdrawOnBehalfOf(
        address spoke,
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf
    ) external returns (uint256, uint256);

    function borrowOnBehalfOf(
        address spoke,
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf
    ) external returns (uint256, uint256);

    function approveWithdraw(address spoke, uint256 reserveId, address spender, uint256 amount) external;
    function approveBorrow(address spoke, uint256 reserveId, address spender, uint256 amount) external;
}

/**
 * @notice Basic integration tests for Aave V4 on Ethereum mainnet.
 * Tests through position managers (Giver/Taker), which is the required
 * path since direct spoke calls need Aave governance whitelisting.
 *
 * Prerequisites for the composer flow:
 * - GiverPM and TakerPM must be active position managers on the spoke (set by Aave governance)
 * - User must approve both PMs via spoke.setUserPositionManager(pm, true)
 * - For supply/repay: composer approves GiverPM for the underlying (ERC20 approve)
 * - For withdraw/borrow: user grants per-reserve allowance on TakerPM to composer
 */
contract AaveV4LendingTest is BaseTest {
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

        // Resolve reserve IDs dynamically
        uint256 usdcAssetId = hub.getAssetId(USDC);
        usdcReserveId = spoke.getReserveId(CORE_HUB, usdcAssetId);

        uint256 wethAssetId = hub.getAssetId(WETH);
        wethReserveId = spoke.getReserveId(CORE_HUB, wethAssetId);

    }

    // ═══════════════════════════════════════════════════
    // Reserve ID validation (no PM needed)
    // ═══════════════════════════════════════════════════

    function test_v4_reserve_ids_are_valid() external view {
        ISpoke.Reserve memory usdcReserve = spoke.getReserve(usdcReserveId);
        assertEq(usdcReserve.underlying, USDC, "USDC reserve should point to USDC");

        ISpoke.Reserve memory wethReserve = spoke.getReserve(wethReserveId);
        assertEq(wethReserve.underlying, WETH, "WETH reserve should point to WETH");

        uint256 reserveCount = spoke.getReserveCount();
        assertGt(reserveCount, 0, "spoke should have reserves");
    }

    // ═══════════════════════════════════════════════════
    // GiverPositionManager tests (deposit / repay)
    // ═══════════════════════════════════════════════════

    function test_v4_deposit_via_giver_pm() external {


        deal(USDC, user, 1000e6);
        uint256 amount = 100e6;

        // User approves GiverPM as their position manager on the spoke
        vm.prank(user);
        spoke.setUserPositionManager(GIVER_PM, true);

        // User approves GiverPM to pull USDC (GiverPM does transferFrom(caller, ...))
        vm.prank(user);
        IERC20All(USDC).approve(GIVER_PM, type(uint256).max);

        uint256 supplyBefore = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        IGiverPositionManager(GIVER_PM).supplyOnBehalfOf(
            MAIN_SPOKE, usdcReserveId, amount, user
        );

        uint256 supplyAfter = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(supplyAfter - supplyBefore, amount, 1, "supply should increase");
        assertApproxEqAbs(balanceBefore - balanceAfter, amount, 1, "balance should decrease");
    }

    function test_v4_repay_via_giver_pm() external {
        // Deposit WETH as collateral, borrow USDC
        _depositViaGiverPM(WETH, user, 10 ether);
        _borrowViaTakerPM(USDC, user, 100e6);

        uint256 amountToRepay = 50e6;
        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        // User approves GiverPM to pull USDC for repay
        vm.prank(user);
        IERC20All(USDC).approve(GIVER_PM, type(uint256).max);

        vm.prank(user);
        IGiverPositionManager(GIVER_PM).repayOnBehalfOf(
            MAIN_SPOKE, usdcReserveId, amountToRepay, user
        );

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, 1, "debt should decrease");
        assertApproxEqAbs(balanceBefore - balanceAfter, amountToRepay, 1, "balance should decrease");
    }

    // ═══════════════════════════════════════════════════
    // TakerPositionManager tests (withdraw / borrow)
    // ═══════════════════════════════════════════════════

    function test_v4_borrow_via_taker_pm() external {
        // Deposit WETH as collateral to support USDC borrow
        _depositViaGiverPM(WETH, user, 10 ether);

        uint256 amountToBorrow = 100e6;

        // User approves TakerPM as their position manager on the spoke
        vm.prank(user);
        spoke.setUserPositionManager(TAKER_PM, true);

        // User grants borrow allowance to themselves (caller) on the TakerPM
        // In the composer flow, this would grant allowance to the composer address
        vm.prank(user);
        ITakerPositionManager(TAKER_PM).approveBorrow(
            MAIN_SPOKE, usdcReserveId, user, type(uint256).max
        );

        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        ITakerPositionManager(TAKER_PM).borrowOnBehalfOf(
            MAIN_SPOKE, usdcReserveId, amountToBorrow, user
        );

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(debtAfter - debtBefore, amountToBorrow, 1, "debt should increase");
        assertApproxEqAbs(balanceAfter - balanceBefore, amountToBorrow, 1, "balance should increase");
    }

    function test_v4_withdraw_via_taker_pm() external {



        _depositViaGiverPM(USDC, user, 1000e6);

        uint256 amountToWithdraw = 100e6;

        // User approves TakerPM as their position manager on the spoke
        vm.prank(user);
        spoke.setUserPositionManager(TAKER_PM, true);

        // User grants withdraw allowance to themselves on the TakerPM
        vm.prank(user);
        ITakerPositionManager(TAKER_PM).approveWithdraw(
            MAIN_SPOKE, usdcReserveId, user, type(uint256).max
        );

        uint256 supplyBefore = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        ITakerPositionManager(TAKER_PM).withdrawOnBehalfOf(
            MAIN_SPOKE, usdcReserveId, amountToWithdraw, user
        );

        uint256 supplyAfter = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        assertApproxEqAbs(supplyBefore - supplyAfter, amountToWithdraw, 1, "supply should decrease");
        assertApproxEqAbs(balanceAfter - balanceBefore, amountToWithdraw, 1, "balance should increase");
    }

    // ═══════════════════════════════════════════════════
    // Max amount tests
    // ═══════════════════════════════════════════════════

    /// @notice Repay max: should repay min(balance, debt), leaving no dust on the composer
    /// This mirrors the max repay case where amount = type(uint112).max
    function test_v4_repay_max_clamps_to_debt() external {
        _depositViaGiverPM(WETH, user, 10 ether);
        _borrowViaTakerPM(USDC, user, 100e6);

        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);
        // Give user more than debt so balance > debt
        deal(USDC, user, debtBefore + 50e6);
        uint256 balanceBefore = IERC20All(USDC).balanceOf(user);

        vm.startPrank(user);
        IERC20All(USDC).approve(GIVER_PM, type(uint256).max);
        // Repay with amount > debt — the spoke caps at actual debt
        IGiverPositionManager(GIVER_PM).repayOnBehalfOf(
            MAIN_SPOKE, usdcReserveId, balanceBefore, user
        );
        vm.stopPrank();

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        // Debt should be fully repaid
        assertEq(debtAfter, 0, "debt should be zero");
        // Should only have spent the debt amount, rest remains
        assertApproxEqAbs(balanceBefore - balanceAfter, debtBefore, 1, "should only deduct actual debt");
    }

    /// @notice Repay max: when balance < debt, should repay only up to balance
    function test_v4_repay_max_clamps_to_balance() external {
        _depositViaGiverPM(WETH, user, 10 ether);
        _borrowViaTakerPM(USDC, user, 100e6);

        // Give user less than debt
        uint256 partialAmount = 40e6;
        deal(USDC, user, partialAmount);
        uint256 debtBefore = spoke.getUserTotalDebt(usdcReserveId, user);

        vm.startPrank(user);
        IERC20All(USDC).approve(GIVER_PM, type(uint256).max);
        // Repay with the partial balance
        IGiverPositionManager(GIVER_PM).repayOnBehalfOf(
            MAIN_SPOKE, usdcReserveId, partialAmount, user
        );
        vm.stopPrank();

        uint256 debtAfter = spoke.getUserTotalDebt(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        // Balance should be zero — all spent on repay
        assertEq(balanceAfter, 0, "balance should be zero");
        // Debt should decrease by partial amount
        assertApproxEqAbs(debtBefore - debtAfter, partialAmount, 1, "debt should decrease by balance");
    }

    /// @notice Withdraw max: should withdraw entire supply position without dust
    function test_v4_withdraw_max_full_supply() external {



        uint256 depositAmount = 500e6;
        _depositViaGiverPM(USDC, user, depositAmount);

        uint256 supplyBefore = spoke.getUserSuppliedAssets(usdcReserveId, user);
        assertApproxEqAbs(supplyBefore, depositAmount, 1, "supply should match deposit");

        // Withdraw the full supply amount (queried from spoke)
        vm.startPrank(user);
        spoke.setUserPositionManager(TAKER_PM, true);
        ITakerPositionManager(TAKER_PM).approveWithdraw(
            MAIN_SPOKE, usdcReserveId, user, type(uint256).max
        );
        ITakerPositionManager(TAKER_PM).withdrawOnBehalfOf(
            MAIN_SPOKE, usdcReserveId, supplyBefore, user
        );
        vm.stopPrank();

        uint256 supplyAfter = spoke.getUserSuppliedAssets(usdcReserveId, user);
        uint256 balanceAfter = IERC20All(USDC).balanceOf(user);

        // No dust should remain in supply
        assertEq(supplyAfter, 0, "supply should be zero after max withdraw");
        assertApproxEqAbs(balanceAfter, depositAmount, 1, "should receive full deposit back");
    }

    // ═══════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════

    function _depositViaGiverPM(address token, address userAddr, uint256 amount) internal {
        uint256 reserveId = _getReserveId(token);
        deal(token, userAddr, amount);

        vm.startPrank(userAddr);
        spoke.setUserPositionManager(GIVER_PM, true);
        IERC20All(token).approve(GIVER_PM, type(uint256).max);
        IGiverPositionManager(GIVER_PM).supplyOnBehalfOf(
            MAIN_SPOKE, reserveId, amount, userAddr
        );
        // V4 requires explicit collateral enable (user can call spoke directly)
        spoke.setUsingAsCollateral(reserveId, true, userAddr);
        vm.stopPrank();
    }

    function _borrowViaTakerPM(address token, address userAddr, uint256 amountToBorrow) internal {
        uint256 reserveId = _getReserveId(token);

        vm.startPrank(userAddr);
        spoke.setUserPositionManager(TAKER_PM, true);
        ITakerPositionManager(TAKER_PM).approveBorrow(
            MAIN_SPOKE, reserveId, userAddr, type(uint256).max
        );
        ITakerPositionManager(TAKER_PM).borrowOnBehalfOf(
            MAIN_SPOKE, reserveId, amountToBorrow, userAddr
        );
        vm.stopPrank();
    }

    function _getReserveId(address token) internal view returns (uint256) {
        uint256 assetId = hub.getAssetId(token);
        return spoke.getReserveId(CORE_HUB, assetId);
    }

}
