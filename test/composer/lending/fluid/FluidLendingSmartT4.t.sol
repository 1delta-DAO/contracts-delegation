// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

interface IFluidVaultT4 {
    function operate(
        uint256 nftId,
        int256 newColToken0,
        int256 newColToken1,
        int256 colSharesMinMax,
        int256 newDebtToken0,
        int256 newDebtToken1,
        int256 debtSharesMinMax,
        address to
    )
        external
        payable
        returns (uint256, int256, int256);

    function operatePerfect(
        uint256 nftId,
        int256 perfectColShares,
        int256 colToken0MinMax,
        int256 colToken1MinMax,
        int256 perfectDebtShares,
        int256 debtToken0MinMax,
        int256 debtToken1MinMax,
        address to
    )
        external
        payable
        returns (uint256, int256[] memory);
}

interface IFluidVaultFactory {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
}

/**
 * @notice Integration tests for FluidSmartLending against a T4 vault on Ethereum mainnet.
 * @dev Vault `0x20b32C597633f12B44CFAFe0ab27408028CA0f6A` has GHO/USDC smart collateral AND
 *      GHO/USDC smart debt. Token ordering (col0 = GHO, col1 = USDC; debt0 = GHO, debt1 = USDC)
 *      follows the vault's name.
 */
contract FluidLendingSmartT4Test is BaseTest {
    IComposerLike internal composer;

    address internal constant VAULT = 0x20b32C597633f12B44CFAFe0ab27408028CA0f6A;
    address internal constant VAULT_FACTORY = 0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d;

    address internal GHO; // col token0 AND debt token0
    address internal USDC; // col token1 AND debt token1

    // Collateral deposit: ~$5k GHO + ~$5k USDC — LP deposits both at current pool ratio.
    uint256 internal constant COL_GHO = 5_000e18; // 5 000 GHO
    uint256 internal constant COL_USDC = 5_000e6; // 5 000 USDC
    // Debt borrow: ~$1k each side.
    uint256 internal constant DEBT_GHO = 1_000e18;
    uint256 internal constant DEBT_USDC = 1_000e6;

    function setUp() public {
        _init(Chains.ETHEREUM_MAINNET, 0, true);
        composer = ComposerPlugin.getComposer(Chains.ETHEREUM_MAINNET);
        GHO = chain.getTokenAddress(Tokens.GHO);
        USDC = chain.getTokenAddress(Tokens.USDC);

        vm.label(address(composer), "Composer");
        vm.label(VAULT, "FluidT4_GHO_USDC_GHO_USDC");
        vm.label(GHO, "GHO");
        vm.label(USDC, "USDC");
    }

    // ─── helpers ────────────────────────────────────────────────────────────

    /// @dev Open a T4 position from `owner_` directly. NFT minted to owner_.
    function _openPositionDirect(address owner_) internal returns (uint256 nftId) {
        deal(GHO, owner_, COL_GHO);
        deal(USDC, owner_, COL_USDC);
        vm.startPrank(owner_);
        IERC20All(GHO).approve(VAULT, type(uint256).max);
        IERC20All(USDC).approve(VAULT, type(uint256).max);
        (nftId,,) = IFluidVaultT4(VAULT).operate(
            0,
            int256(COL_GHO),
            int256(COL_USDC),
            int256(1), // min col shares
            int256(DEBT_GHO),
            int256(DEBT_USDC),
            int256(type(int128).max), // max debt shares — loose upper bound (below the FLUID_SMART_USE_BALANCE sentinel)
            owner_
        );
        vm.stopPrank();
        require(nftId != 0, "open T4 failed");
    }

    // ─── 1. Open balanced position via composer (combined col deposit + debt borrow) ───

    /// @dev Fills the T4 `operate` slot arrays for an open-balanced-position call.
    function _t4OpenAmounts() internal pure returns (address[6] memory tokens, int256[6] memory amounts) {
        // tokens: col0/col1 are the supply side; debt slots don't use sentinel so stay 0.
        // amounts: [newColToken0, newColToken1, colSharesMinMax, newDebtToken0, newDebtToken1, debtSharesMinMax]
        amounts[2] = int256(1); // min col shares — loose
        // type(int256).max is reserved by the composer as FLUID_SMART_USE_BALANCE, so cap
        // debt shares with a large-but-not-sentinel value.
        amounts[5] = int256(type(int128).max);
    }

    function test_fluid_smart_t4_open_balanced_position_and_sweep() public {
        deal(GHO, user, COL_GHO);
        deal(USDC, user, COL_USDC);
        vm.startPrank(user);
        IERC20All(GHO).approve(address(composer), type(uint256).max);
        IERC20All(USDC).approve(address(composer), type(uint256).max);
        vm.stopPrank();

        (address[6] memory tokens, int256[6] memory amounts) = _t4OpenAmounts();
        tokens[0] = GHO;
        tokens[1] = USDC;
        amounts[0] = int256(COL_GHO);
        amounts[1] = int256(COL_USDC);
        amounts[3] = int256(DEBT_GHO);
        amounts[4] = int256(DEBT_USDC);

        bytes memory pulls = abi.encodePacked(
            CalldataLib.encodeTransferIn(GHO, address(composer), COL_GHO),
            CalldataLib.encodeTransferIn(USDC, address(composer), COL_USDC)
        );
        bytes memory opAndSweep = abi.encodePacked(
            CalldataLib.encodeApprove(GHO, VAULT),
            CalldataLib.encodeApprove(USDC, VAULT),
            CalldataLib.encodeFluidSmartOperateT4(0, 0, user, VAULT, tokens, amounts),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user)
        );

        uint256 nftsBefore = IFluidVaultFactory(VAULT_FACTORY).balanceOf(user);
        uint256 ghoBefore = IERC20All(GHO).balanceOf(user);
        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(pulls, opAndSweep));

        assertEq(IFluidVaultFactory(VAULT_FACTORY).balanceOf(user) - nftsBefore, 1, "user got new NFT");
        assertApproxEqAbs(
            ghoBefore - IERC20All(GHO).balanceOf(user), COL_GHO - DEBT_GHO, 1, "GHO net-outflow ~ col-debt"
        );
        assertApproxEqAbs(
            usdcBefore - IERC20All(USDC).balanceOf(user), COL_USDC - DEBT_USDC, 1, "USDC net-outflow ~ col-debt"
        );
        assertEq(IERC20All(GHO).balanceOf(address(composer)), 0, "composer holds no GHO");
        assertEq(IERC20All(USDC).balanceOf(address(composer)), 0, "composer holds no USDC");
    }

    // ─── 2. Open using FLUID_SMART_USE_BALANCE sentinel (simulates swap → deposit all) ───

    function test_fluid_smart_t4_open_with_balance_sentinel() public {
        // Pre-fund composer to simulate post-swap state.
        deal(GHO, address(composer), COL_GHO);
        deal(USDC, address(composer), COL_USDC);

        (address[6] memory tokens, int256[6] memory amounts) = _t4OpenAmounts();
        tokens[0] = GHO;
        tokens[1] = USDC;
        amounts[0] = CalldataLib.FLUID_SMART_USE_BALANCE;
        amounts[1] = CalldataLib.FLUID_SMART_USE_BALANCE;
        amounts[3] = int256(DEBT_GHO);
        amounts[4] = int256(DEBT_USDC);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeApprove(GHO, VAULT),
            CalldataLib.encodeApprove(USDC, VAULT),
            CalldataLib.encodeFluidSmartOperateT4(0, 0, user, VAULT, tokens, amounts),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user)
        );

        uint256 nftsBefore = IFluidVaultFactory(VAULT_FACTORY).balanceOf(user);
        uint256 ghoBefore = IERC20All(GHO).balanceOf(user);
        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(IFluidVaultFactory(VAULT_FACTORY).balanceOf(user) - nftsBefore, 1, "user got new NFT");
        assertEq(IERC20All(GHO).balanceOf(user) - ghoBefore, DEBT_GHO, "user received GHO borrow");
        assertEq(IERC20All(USDC).balanceOf(user) - usdcBefore, DEBT_USDC, "user received USDC borrow");
        assertEq(IERC20All(GHO).balanceOf(address(composer)), 0, "composer GHO consumed");
        assertEq(IERC20All(USDC).balanceOf(address(composer)), 0, "composer USDC consumed");
    }

    // ─── 3. NFT-custody: shrink-col via operate (partial withdraw of both col tokens) ───

    /// @dev Withdraw ~10% of each col token via a balanced negative-amount operate call.
    function _buildT4ShrinkColOps(uint256 nftId, uint256 token0Out, uint256 token1Out)
        internal
        view
        returns (bytes memory)
    {
        address[6] memory tokens;
        int256[6] memory amounts;
        amounts[0] = -int256(token0Out);
        amounts[1] = -int256(token1Out);
        amounts[2] = -int256(type(int128).max); // col shares burn cap — loose
        // debt slots untouched
        amounts[3] = int256(0);
        amounts[4] = int256(0);
        amounts[5] = int256(0);
        return abi.encodePacked(
            CalldataLib.encodeFluidSmartOperateT4(0, nftId, user, VAULT, tokens, amounts),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user)
        );
    }

    function test_fluid_smart_t4_nft_custody_shrink_col_via_operate() public {
        uint256 nftId = _openPositionDirect(user);

        uint256 gOut = COL_GHO / 10;
        uint256 uOut = COL_USDC / 10;

        uint256 ghoBefore = IERC20All(GHO).balanceOf(user);
        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(
            user, address(composer), nftId, _buildT4ShrinkColOps(nftId, gOut, uOut)
        );

        assertGt(IERC20All(GHO).balanceOf(user) - ghoBefore, 0, "some GHO returned");
        assertGt(IERC20All(USDC).balanceOf(user) - usdcBefore, 0, "some USDC returned");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "nft swept back");
    }

    // ─── 4. NFT-custody: two-phase full close via operatePerfect ───
    //
    // Doing the full close in a single `operatePerfect` call (both `perfectColShares` and
    // `perfectDebtShares` set to `int.min` at once) trips a Fluid DEX invariant on a same-block
    // open→close. Splitting into two sequential `operatePerfect` calls — first repay-all on the
    // smart-debt side while leaving col untouched, then burn-all on the smart-col side with
    // debt already zero — sidesteps that path and is the documented "safe close" pattern for
    // T4 smart-both positions.

    /// @dev Phase 1: repay-all debt only. Col slots 0; debt slots drive the call.
    /// @dev IMPORTANT: per-token MinMax for debt-repay (burning shares, paying tokens IN) must
    ///      be NEGATIVE — the sign matches the action (burn) direction, magnitude is the cap.
    ///      Passing positive values reverts in Fluid's `_debtOperatePerfectPayback` with
    ///      `VaultDex__InvalidOperateAmount`.
    function _t4ClosePhase1RepayDebt(uint256 nftId) internal view returns (bytes memory) {
        address[6] memory tokens;
        int256[6] memory amounts;
        // col axis untouched
        amounts[0] = int256(0);
        amounts[1] = int256(0);
        amounts[2] = int256(0);
        // debt axis: burn ALL shares; per-token MAX-IN cap is encoded as a NEGATIVE magnitude.
        amounts[3] = type(int256).min;
        amounts[4] = -int256(type(int128).max);
        amounts[5] = -int256(type(int128).max);
        return CalldataLib.encodeFluidSmartOperatePerfectT4(0, nftId, user, VAULT, tokens, amounts);
    }

    /// @dev Phase 2: burn-all col only. Debt slots 0 (already zero post-phase-1).
    function _t4ClosePhase2BurnCol(uint256 nftId) internal view returns (bytes memory) {
        address[6] memory tokens;
        int256[6] memory amounts;
        // col axis: burn ALL shares, withdraw both tokens with loose slippage.
        amounts[0] = type(int256).min;
        amounts[1] = -int256(1);
        amounts[2] = -int256(1);
        // debt axis untouched
        amounts[3] = int256(0);
        amounts[4] = int256(0);
        amounts[5] = int256(0);
        return CalldataLib.encodeFluidSmartOperatePerfectT4(0, nftId, user, VAULT, tokens, amounts);
    }

    function _buildT4TwoPhaseClose(uint256 nftId, uint256 ghoBuffer, uint256 usdcBuffer)
        internal
        view
        returns (bytes memory)
    {
        bytes memory pulls = abi.encodePacked(
            CalldataLib.encodeTransferIn(GHO, address(composer), ghoBuffer),
            CalldataLib.encodeTransferIn(USDC, address(composer), usdcBuffer),
            CalldataLib.encodeApprove(GHO, VAULT),
            CalldataLib.encodeApprove(USDC, VAULT)
        );
        return abi.encodePacked(
            pulls,
            _t4ClosePhase1RepayDebt(nftId),
            _t4ClosePhase2BurnCol(nftId),
            // Sweep any repay-buffer dust + the (now-empty) NFT.
            CalldataLib.encodeSweep(GHO, user, 0, SweepType.VALIDATE),
            CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user)
        );
    }

    function test_fluid_smart_t4_nft_custody_full_close_two_phase() public {
        uint256 nftId = _openPositionDirect(user);

        // Advance past any same-block / oracle-dwell guards the vault enforces between op and
        // close. Fluid uses a TWAP-style center-price observation; closing in the same block as
        // opening trips a freshness check inside `operatePerfect`.
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 300);

        // Pre-fund user with debt tokens + generous buffer. Smart-debt repay pulls an amount
        // determined by the DEX pool's current ratio, which can drift above the 1:1 borrow.
        uint256 ghoBuffer = DEBT_GHO * 2;
        uint256 usdcBuffer = DEBT_USDC * 2;
        deal(GHO, user, ghoBuffer);
        deal(USDC, user, usdcBuffer);
        vm.startPrank(user);
        IERC20All(GHO).approve(address(composer), type(uint256).max);
        IERC20All(USDC).approve(address(composer), type(uint256).max);
        vm.stopPrank();

        bytes memory innerOps = _buildT4TwoPhaseClose(nftId, ghoBuffer, usdcBuffer);

        // Net-token-flow direction depends on pool ratio at close — for a col-heavy LP whose
        // ratio drifts, the user can end up with more of one token and less of the other. The
        // primary close invariants are: composer fully cleared and NFT returned.
        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, innerOps);

        assertEq(IERC20All(GHO).balanceOf(address(composer)), 0, "composer GHO fully swept");
        assertEq(IERC20All(USDC).balanceOf(address(composer)), 0, "composer USDC fully swept");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "empty NFT swept back");
    }
}
