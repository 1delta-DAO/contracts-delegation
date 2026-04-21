// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

interface IFluidVaultT3 {
    function operate(
        uint256 nftId,
        int256 newCol,
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
        int256 newCol,
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
    function totalSupply() external view returns (uint256);
}

/**
 * @notice Integration tests for FluidSmartLending against a T3 vault on Ethereum mainnet.
 * @dev Vault `0x221E35b5655A1eEB3C42c4DeFc39648531f6C9CF` has wstETH SIMPLE collateral and
 *      USDC/USDT SMART debt. Token ordering (debt0 = USDC, debt1 = USDT) follows the vault's
 *      name. T3's slot layout is the mirror of T2:
 *          operate         → [newCol, newDebtToken0, newDebtToken1, debtSharesMinMax]
 *          operatePerfect  → [newCol, perfectDebtShares, debtToken0MinMax, debtToken1MinMax]
 *      The col slot is always slot 0 (single token), which doubles as the offset-correctness
 *      anchor for the balance-sentinel tests below.
 */
contract FluidLendingSmartT3Test is BaseTest {
    IComposerLike internal composer;

    address internal constant VAULT = 0x221E35b5655A1eEB3C42c4DeFc39648531f6C9CF;
    address internal constant VAULT_FACTORY = 0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d;

    address internal WSTETH; // simple col
    address internal USDC; // smart debt token0
    address internal USDT; // smart debt token1

    uint256 internal constant COL_AMOUNT = 1e18; // 1 wstETH
    uint256 internal constant DEBT_USDC = 500e6;
    uint256 internal constant DEBT_USDT = 500e6;

    function setUp() public {
        _init(Chains.ETHEREUM_MAINNET, 0, true);
        composer = ComposerPlugin.getComposer(Chains.ETHEREUM_MAINNET);
        WSTETH = chain.getTokenAddress(Tokens.WSTETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        USDT = chain.getTokenAddress(Tokens.USDT);

        vm.label(address(composer), "Composer");
        vm.label(VAULT, "FluidT3_wstETH_USDC_USDT");
        vm.label(WSTETH, "wstETH");
        vm.label(USDC, "USDC");
        vm.label(USDT, "USDT");
    }

    // ─── helpers ────────────────────────────────────────────────────────────

    /// @dev Open a T3 position from `owner_` directly. NFT minted to owner_.
    function _openPositionDirect(address owner_) internal returns (uint256 nftId) {
        deal(WSTETH, owner_, COL_AMOUNT);
        vm.startPrank(owner_);
        IERC20All(WSTETH).approve(VAULT, type(uint256).max);
        (nftId,,) = IFluidVaultT3(VAULT).operate(
            0,
            int256(COL_AMOUNT),
            int256(DEBT_USDC),
            int256(DEBT_USDT),
            int256(type(int128).max), // max debt shares cap — loose
            owner_
        );
        vm.stopPrank();
        require(nftId != 0, "open T3 failed");
    }

    /// @dev USDT's `approve` returns no bool — IERC20All's typed interface panics on the empty
    ///      return data, so route any USDT approve from the test contract through a low-level call.
    function _userApproveUsdt(address spender) internal {
        vm.prank(user);
        (bool ok,) = USDT.call(abi.encodeWithSignature("approve(address,uint256)", spender, type(uint256).max));
        require(ok, "usdt approve failed");
    }

    // ─── 1. Open balanced position via composer ────────────────────────────
    //
    // Anchors slot ordering for T3 `operate`:
    //   slot 0 = newCol        ↔ tokens[0] (WSTETH) — only consulted on sentinel
    //   slot 1 = newDebtToken0 ↔ tokens[1] (USDC)
    //   slot 2 = newDebtToken1 ↔ tokens[2] (USDT)
    //   slot 3 = debtSharesMinMax — slippage, no token

    function test_fluid_smart_t3_open_balanced_position_and_sweep() public {
        deal(WSTETH, user, COL_AMOUNT);
        vm.prank(user);
        IERC20All(WSTETH).approve(address(composer), type(uint256).max);

        address[4] memory tokens; // all zeros — no slot uses the sentinel
        int256[4] memory amounts;
        amounts[0] = int256(COL_AMOUNT);
        amounts[1] = int256(DEBT_USDC);
        amounts[2] = int256(DEBT_USDT);
        amounts[3] = int256(type(int128).max); // loose debtSharesMinMax cap

        uint256 predictedNftId = IFluidVaultFactory(VAULT_FACTORY).totalSupply() + 1;
        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(WSTETH, address(composer), COL_AMOUNT),
            CalldataLib.encodeApprove(WSTETH, VAULT),
            CalldataLib.encodeFluidSmartOperateT3(0, 0, user, VAULT, tokens, amounts),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user, predictedNftId)
        );

        uint256 nftsBefore = IFluidVaultFactory(VAULT_FACTORY).balanceOf(user);
        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);
        uint256 usdtBefore = IERC20All(USDT).balanceOf(user);

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(IFluidVaultFactory(VAULT_FACTORY).balanceOf(user) - nftsBefore, 1, "user got new NFT");
        assertEq(IERC20All(USDC).balanceOf(user) - usdcBefore, DEBT_USDC, "user received USDC borrow");
        assertEq(IERC20All(USDT).balanceOf(user) - usdtBefore, DEBT_USDT, "user received USDT borrow");
        assertEq(IERC20All(WSTETH).balanceOf(address(composer)), 0, "composer holds no wstETH");
    }

    // ─── 2. Open with FLUID_SMART_USE_BALANCE on the col slot (slot 0) ─────
    //
    // Verifies that the composer correctly looks up `balanceOf(WSTETH)` for slot 0, NOT for
    // some other slot. If the offset arithmetic were off (e.g. tokens read from slot 1 instead
    // of slot 0), the lookup would target USDC and the deposit would either revert or use the
    // wrong amount.

    function test_fluid_smart_t3_open_with_col_balance_sentinel() public {
        // Pre-fund composer to simulate post-swap state (composer ends with wstETH after a swap).
        deal(WSTETH, address(composer), COL_AMOUNT);

        address[4] memory tokens;
        tokens[0] = WSTETH; // slot 0 = col → balanceOf(WSTETH)
        int256[4] memory amounts;
        amounts[0] = CalldataLib.FLUID_SMART_USE_BALANCE; // composer resolves to balance
        amounts[1] = int256(DEBT_USDC);
        amounts[2] = int256(DEBT_USDT);
        amounts[3] = int256(type(int128).max);

        uint256 predictedNftId = IFluidVaultFactory(VAULT_FACTORY).totalSupply() + 1;
        bytes memory data = abi.encodePacked(
            CalldataLib.encodeApprove(WSTETH, VAULT),
            CalldataLib.encodeFluidSmartOperateT3(0, 0, user, VAULT, tokens, amounts),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user, predictedNftId)
        );

        uint256 nftsBefore = IFluidVaultFactory(VAULT_FACTORY).balanceOf(user);
        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);
        uint256 usdtBefore = IERC20All(USDT).balanceOf(user);

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(IFluidVaultFactory(VAULT_FACTORY).balanceOf(user) - nftsBefore, 1, "user got new NFT");
        assertEq(IERC20All(USDC).balanceOf(user) - usdcBefore, DEBT_USDC, "user received USDC borrow");
        assertEq(IERC20All(USDT).balanceOf(user) - usdtBefore, DEBT_USDT, "user received USDT borrow");
        // Composer's wstETH was consumed entirely (the balance sentinel resolved correctly to slot 0).
        assertEq(IERC20All(WSTETH).balanceOf(address(composer)), 0, "composer wstETH consumed");
    }

    // ─── 3. NFT-custody: top up col using balance sentinel on existing position ─
    //
    // Same offset-anchor as test 2, but on an existing nftId via the safeTransferFrom path.
    // Ensures the sentinel + token-slot lookup also works inside the receiver hook, where the
    // calldata enters via `data` rather than directly from `deltaCompose`.

    function test_fluid_smart_t3_nft_custody_topup_col_with_balance_sentinel() public {
        uint256 nftId = _openPositionDirect(user);

        // Pre-fund composer with extra wstETH to simulate "user just swapped into wstETH".
        uint256 topUp = 0.5 ether;
        deal(WSTETH, address(composer), topUp);

        address[4] memory tokens;
        tokens[0] = WSTETH;
        int256[4] memory amounts;
        amounts[0] = CalldataLib.FLUID_SMART_USE_BALANCE;
        // debt slots stay 0 — col-only top-up
        amounts[1] = int256(0);
        amounts[2] = int256(0);
        amounts[3] = int256(0);

        bytes memory innerOps = abi.encodePacked(
            CalldataLib.encodeApprove(WSTETH, VAULT),
            CalldataLib.encodeFluidSmartOperateT3(0, nftId, user, VAULT, tokens, amounts),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user, nftId)
        );

        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, innerOps);

        assertEq(IERC20All(WSTETH).balanceOf(address(composer)), 0, "composer wstETH consumed");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "nft swept back");
    }

    // ─── 4. NFT-custody: two-phase full close via operatePerfect ───────────
    //
    // operatePerfect T3 amount layout: [newCol, perfectDebtShares, debtToken0MinMax, debtToken1MinMax]
    //   slot 0 = newCol — simple col side (T1-style sentinels work)
    //   slot 1 = perfectDebtShares — smart debt share param (int.min = repay all)
    //   slot 2 = debtToken0MinMax — smart-debt slippage on token0 (USDC)
    //   slot 3 = debtToken1MinMax — smart-debt slippage on token1 (USDT)
    //
    // Same as T4: split the close into two ops to dodge the same-block DEX invariant —
    // first repay-all the smart debt (col untouched), then withdraw-all the simple col.

    /// @dev Phase 1: repay-all smart debt only. Col slot 0; debt slots drive the call.
    /// @dev Per-token MinMax for debt-repay must be NEGATIVE (sign matches the burn-shares
    ///      action direction), magnitude = max-in cap.
    function _t3ClosePhase1RepayDebt(uint256 nftId) internal view returns (bytes memory) {
        address[4] memory tokens;
        int256[4] memory amounts;
        amounts[0] = int256(0); // col untouched
        amounts[1] = type(int256).min; // perfectDebtShares = burn ALL
        amounts[2] = -int256(type(int128).max); // USDC max-in cap (negative)
        amounts[3] = -int256(type(int128).max); // USDT max-in cap (negative)
        return CalldataLib.encodeFluidSmartOperatePerfectT3(0, nftId, user, VAULT, tokens, amounts);
    }

    /// @dev Phase 2: withdraw-all simple col only. Debt slots 0 (already zero post-phase-1).
    function _t3ClosePhase2WithdrawCol(uint256 nftId) internal view returns (bytes memory) {
        address[4] memory tokens;
        int256[4] memory amounts;
        // Simple col side accepts T1-style int.min sentinel for "withdraw all".
        amounts[0] = type(int256).min;
        amounts[1] = int256(0);
        amounts[2] = int256(0);
        amounts[3] = int256(0);
        return CalldataLib.encodeFluidSmartOperatePerfectT3(0, nftId, user, VAULT, tokens, amounts);
    }

    function _buildT3TwoPhaseClose(uint256 nftId, uint256 usdcBuffer, uint256 usdtBuffer)
        internal
        view
        returns (bytes memory)
    {
        bytes memory pulls = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDC, address(composer), usdcBuffer),
            CalldataLib.encodeTransferIn(USDT, address(composer), usdtBuffer),
            CalldataLib.encodeApprove(USDC, VAULT),
            CalldataLib.encodeApprove(USDT, VAULT)
        );
        return abi.encodePacked(
            pulls,
            _t3ClosePhase1RepayDebt(nftId),
            _t3ClosePhase2WithdrawCol(nftId),
            CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE),
            CalldataLib.encodeSweep(USDT, user, 0, SweepType.VALIDATE),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user, nftId)
        );
    }

    function test_fluid_smart_t3_nft_custody_full_close_two_phase() public {
        uint256 nftId = _openPositionDirect(user);

        // Generous buffers — smart-debt repay settles against the DEX pool's current ratio.
        uint256 usdcBuffer = DEBT_USDC * 2;
        uint256 usdtBuffer = DEBT_USDT * 2;
        deal(USDC, user, usdcBuffer);
        deal(USDT, user, usdtBuffer);
        vm.prank(user);
        IERC20All(USDC).approve(address(composer), type(uint256).max);
        _userApproveUsdt(address(composer)); // USDT non-standard approve

        bytes memory innerOps = _buildT3TwoPhaseClose(nftId, usdcBuffer, usdtBuffer);

        uint256 wstBefore = IERC20All(WSTETH).balanceOf(user);

        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, innerOps);

        // Col returned in full (simple side, exact int.min sentinel).
        assertGt(IERC20All(WSTETH).balanceOf(user) - wstBefore, 0, "wstETH returned");
        assertEq(IERC20All(USDC).balanceOf(address(composer)), 0, "composer USDC fully swept");
        assertEq(IERC20All(USDT).balanceOf(address(composer)), 0, "composer USDT fully swept");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "empty NFT swept back");
    }
}
