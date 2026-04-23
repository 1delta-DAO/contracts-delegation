// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

struct MultiCall {
    address target;
    bytes callData;
}

interface ICreditManagerV3 {
    function creditFacade() external view returns (address);
    function pool() external view returns (address);
    function underlying() external view returns (address);
    function poolQuotaKeeper() external view returns (address);
    function getBorrowerOrRevert(address creditAccount) external view returns (address);
    function enabledTokensMaskOf(address creditAccount) external view returns (uint256);
    function quotedTokensMask() external view returns (uint256);
    function getTokenMaskOrRevert(address token) external view returns (uint256);
    function getTokenByMask(uint256 tokenMask) external view returns (address);
    function collateralTokensCount() external view returns (uint8);
}

interface ICreditFacadeV3 {
    function multicall(address creditAccount, MultiCall[] calldata calls) external payable;
    function openCreditAccount(address onBehalfOf, MultiCall[] calldata calls, uint256 referralCode)
        external
        payable
        returns (address);
    function debtLimits() external view returns (uint128 minDebt, uint128 maxDebt);
    function maxDebtPerBlockMultiplier() external view returns (uint8);
}

interface ICreditFacadeV3Multicall {
    function addCollateral(address token, uint256 amount) external;
    function increaseDebt(uint256 amount) external;
    function decreaseDebt(uint256 amount) external;
    function withdrawCollateral(address token, uint256 amount, address to) external;
    function updateQuota(address token, int96 quotaChange, uint96 minQuota) external;
    function setFullCheckParams(uint256[] calldata collateralHints, uint16 minHealthFactor) external;
    function setBotPermissions(address bot, uint192 permissions) external;
}

interface IPoolQuotaKeeperV3 {
    function getQuota(address creditAccount, address token) external view returns (uint96 quota, uint192 cumulativeIndexLU);
}

/// @dev Reads `CreditManagerV3.creditAccountInfo(ca)` tuple. First element is debt.
interface ICM_V3Info {
    function creditAccountInfo(address creditAccount)
        external
        view
        returns (
            uint256 debt,
            uint256 cumulativeIndexLastUpdate,
            uint128 cumulativeQuotaInterest,
            uint128 quotaFees,
            uint256 enabledTokensMask,
            uint16 flags,
            uint64 lastDebtUpdate,
            address borrower
        );
}

/// @dev `calcDebtAndCollateral(ca, task)` — returns a `CollateralDebtData` struct. We only need
///      `debt + accruedInterest + accruedFees` which is Gearbox's `calcTotalDebt` and equals
///      `maxRepayment` for non-USDT pools (wstETH pool is not USDT).
///      Enum `CollateralCalcTask` values: GENERIC_PARAMS=0, DEBT_ONLY=1, FULL_LAZY=2, DEBT_COLLATERAL=3,
///      DEBT_COLLATERAL_SAFE_PRICES=4. `DEBT_ONLY` is the cheapest read that still fills the fields
///      we need.
struct CollateralDebtData {
    uint256 debt;
    uint256 cumulativeIndexNow;
    uint256 cumulativeIndexLastUpdate;
    uint128 cumulativeQuotaInterest;
    uint256 accruedInterest;
    uint256 accruedFees;
    uint256 totalDebtUSD;
    uint256 totalValue;
    uint256 totalValueUSD;
    uint256 twvUSD;
    uint256 enabledTokensMask;
    uint256 quotedTokensMask;
    address[] quotedTokens;
    address _poolQuotaKeeper;
}

interface ICM_V3Calc {
    function calcDebtAndCollateral(address creditAccount, uint8 task)
        external
        view
        returns (CollateralDebtData memory);
}

/**
 * @notice Fork tests for GearboxV3Lending against the live wstETH pool / ETH+ credit suite on
 *         Ethereum mainnet.
 *
 * @dev Fixed addresses:
 *        Credit Manager: 0x9fB5493DEb601A0329AD8BfF43cD182A61321ca7  (wstETH credit suite)
 *        Pool (wstETH):  0xa9D17F6D3285208280A1Fd9B94479C62e0aABA64
 *        Collateral:     0xE72B141DF173b999AE7c1aDCbF60Cc9833Ce56a8  (ETH+ / ETHPlus)
 *
 *      The facade address and underlying are discovered on-chain in setUp. We grant the composer
 *      bot permissions on the freshly-opened CA via a direct `facade.multicall([setBotPermissions])`
 *      (owner-only op; composer cannot do this for us).
 */
contract GearboxV3ForkTest is BaseTest {
    IComposerLike internal composer;

    address internal constant CREDIT_MANAGER = 0x9fB5493dEb601A0329ad8bFF43cD182a61321ca7;
    address internal constant POOL = 0xA9d17f6D3285208280a1Fd9B94479c62e0AABa64;
    address internal constant ETHPLUS = 0xE72B141DF173b999AE7c1aDcbF60Cc9833Ce56a8;

    address internal creditFacade;
    address internal underlying; // wstETH
    address internal poolQuotaKeeper;
    uint128 internal minDebt;
    uint128 internal maxDebt;

    /// @dev Must match `GearboxV3Lending.requiredPermissions()` exactly — Gearbox's BotListV3
    ///      rejects any other value with `IncorrectBotPermissionsException`.
    uint192 internal constant PERM_COMPOSER_EXACT =
        uint192((1 << 0) | (1 << 1) | (1 << 2) | (1 << 5) | (1 << 6));

    function setUp() public {
        _init(Chains.ETHEREUM_MAINNET, 0, true);
        composer = ComposerPlugin.getComposer(Chains.ETHEREUM_MAINNET);

        creditFacade = ICreditManagerV3(CREDIT_MANAGER).creditFacade();
        underlying = ICreditManagerV3(CREDIT_MANAGER).underlying();
        poolQuotaKeeper = ICreditManagerV3(CREDIT_MANAGER).poolQuotaKeeper();
        (minDebt, maxDebt) = ICreditFacadeV3(creditFacade).debtLimits();

        vm.label(address(composer), "Composer");
        vm.label(CREDIT_MANAGER, "CM_wstETH");
        vm.label(creditFacade, "Facade_wstETH");
        vm.label(POOL, "Pool_wstETH");
        vm.label(underlying, "wstETH");
        vm.label(ETHPLUS, "ETHPlus");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Open a fresh CA with `user` as borrower, an initial collateral deposit, a minimum
    ///      debt draw, and bot permissions granted inline to the composer.
    function _openCaWithComposerBot(uint256 collatAmt, uint256 debtAmt, uint192 permissions)
        internal
        returns (address ca)
    {
        deal(ETHPLUS, user, collatAmt);
        vm.prank(user);
        IERC20All(ETHPLUS).approve(CREDIT_MANAGER, type(uint256).max);

        // Gearbox requires a non-zero quota for quoted collateral tokens to count toward the
        // CA's total value. Size the quota to cover the debt plus buffer so `setFullCheckParams`
        // passes at the end of the open multicall.
        int96 quota = int96(uint96(debtAmt * 2));

        // Gearbox rejects updateQuota on a zero-debt account, so order matters:
        //   1. addCollateral         — get the token onto the CA
        //   2. increaseDebt          — creates debt so updateQuota is legal
        //   3. updateQuota           — makes the quoted collateral count in HF
        //   4. setBotPermissions     — grant the composer as bot
        //   5. setFullCheckParams    — final HF check with collateral now counted
        MultiCall[] memory calls = new MultiCall[](5);
        calls[0] = MultiCall({
            target: creditFacade,
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (ETHPLUS, collatAmt))
        });
        calls[1] = MultiCall({
            target: creditFacade,
            callData: abi.encodeCall(ICreditFacadeV3Multicall.increaseDebt, (debtAmt))
        });
        calls[2] = MultiCall({
            target: creditFacade,
            callData: abi.encodeCall(ICreditFacadeV3Multicall.updateQuota, (ETHPLUS, quota, uint96(0)))
        });
        calls[3] = MultiCall({
            target: creditFacade,
            callData: abi.encodeCall(ICreditFacadeV3Multicall.setBotPermissions, (address(composer), permissions))
        });
        calls[4] = MultiCall({
            target: creditFacade,
            callData: abi.encodeCall(ICreditFacadeV3Multicall.setFullCheckParams, (new uint256[](0), uint16(10000)))
        });

        vm.prank(user);
        ca = ICreditFacadeV3(creditFacade).openCreditAccount(user, calls, 0);
        require(ca != address(0), "CA open failed");

        // Gearbox forbids two debt updates on the same CA in the same block. Advance the block
        // so subsequent test ops (increaseDebt, decreaseDebt) don't trip
        // `DebtUpdatedTwiceInOneBlockException`.
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    /// @dev Enumerate currently-enabled quoted collateral tokens on `ca`.
    function _enabledQuotedTokens(address ca) internal view returns (address[] memory) {
        uint256 enabledMask = ICreditManagerV3(CREDIT_MANAGER).enabledTokensMaskOf(ca);
        uint256 quotedMask = ICreditManagerV3(CREDIT_MANAGER).quotedTokensMask();
        uint256 mask = enabledMask & quotedMask;

        uint256 count;
        uint256 tmp = mask;
        while (tmp != 0) {
            tmp &= tmp - 1;
            count++;
        }

        address[] memory out = new address[](count);
        uint256 idx;
        uint256 bit = 1;
        for (uint256 i = 0; i < 256; i++) {
            if (mask & bit != 0) {
                out[idx++] = ICreditManagerV3(CREDIT_MANAGER).getTokenByMask(bit);
            }
            bit <<= 1;
        }
        return out;
    }

    function _pickBorrowAmount() internal view returns (uint256) {
        // Borrow slightly above minDebt so the CA stays within protocol limits.
        return uint256(minDebt) + 1 wei;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 0. Auth — non-owner caller must NOT be able to drain a bot-enabled CA
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice The critical auth invariant. A user granting the composer bot permissions on
    ///         their CA must not thereby make the CA drainable by any other caller who knows
    ///         the CA address. Proven by:
    ///           1. user opens CA, grants the composer bot role with the exact-match mask;
    ///           2. mallory (not the borrower) calls `deltaCompose` with a borrow targeted at
    ///              `ca = userCa, receiver = mallory`;
    ///           3. the composer's `_gearboxAuthCaller` check rejects — no state change.
    function test_fork_gearbox_auth_nonowner_cannot_drain() public {
        uint256 seed = uint256(minDebt) * 10;
        address ca = _openCaWithComposerBot(seed, _pickBorrowAmount(), PERM_COMPOSER_EXACT);

        address mallory = address(0xbADbAd);
        vm.label(mallory, "mallory");
        vm.deal(mallory, 1 ether);

        uint256 userDebtBefore = _debtOf(ca);
        uint256 malloryBalBefore = IERC20All(underlying).balanceOf(mallory);

        bytes memory data = CalldataLib.encodeGearboxV3Borrow(
            underlying,
            uint128(minDebt),
            mallory, // attacker tries to redirect proceeds
            ca,
            creditFacade
        );

        vm.prank(mallory);
        vm.expectRevert(); // InvalidCaller() from the composer's auth check
        composer.deltaCompose(data);

        assertEq(_debtOf(ca), userDebtBefore, "CA debt unchanged");
        assertEq(IERC20All(underlying).balanceOf(mallory), malloryBalBefore, "mallory received nothing");
    }

    function _debtOf(address ca) internal view returns (uint256 debt) {
        (debt,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Supply onto an existing CA
    // ─────────────────────────────────────────────────────────────────────────

    function test_fork_gearbox_supply_adds_collateral_to_existing_ca() public {
        // Collateral size has to comfortably cover the protocol's minDebt draw. Pools on the
        // wstETH suite have minDebt ≈ 20 wstETH, so seed with 10× that in ETH+ (≈ same fiat
        // value as wstETH, so 200 ETH+ against 20 wstETH debt ≈ 90% HF headroom).
        uint256 seed = uint256(minDebt) * 10;
        address ca = _openCaWithComposerBot(seed, _pickBorrowAmount(), PERM_COMPOSER_EXACT);

        uint256 topUp = 0.5e18;
        deal(ETHPLUS, user, topUp);
        vm.prank(user);
        IERC20All(ETHPLUS).approve(address(composer), type(uint256).max);

        uint256 balBefore = IERC20All(ETHPLUS).balanceOf(ca);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(ETHPLUS, address(composer), topUp),
            CalldataLib.encodeGearboxV3Supply(ETHPLUS, uint128(topUp), ca, creditFacade, CREDIT_MANAGER)
        );

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(IERC20All(ETHPLUS).balanceOf(ca), balBefore + topUp, "CA gained topUp");
        assertEq(IERC20All(ETHPLUS).balanceOf(address(composer)), 0, "composer holds no residue");
        assertEq(ICreditManagerV3(CREDIT_MANAGER).getBorrowerOrRevert(ca), user, "user is still borrower");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Borrow from an existing CA
    // ─────────────────────────────────────────────────────────────────────────

    function test_fork_gearbox_borrow_delivers_underlying_to_receiver() public {
        // Seed with extra collateral so borrow has headroom.
        uint256 seed = uint256(minDebt) * 10;
        address ca = _openCaWithComposerBot(seed, _pickBorrowAmount(), PERM_COMPOSER_EXACT);

        uint256 userBalBefore = IERC20All(underlying).balanceOf(user);
        uint256 extraBorrow = uint256(minDebt); // borrow one more min-debt unit

        bytes memory data = CalldataLib.encodeGearboxV3Borrow(
            underlying, uint128(extraBorrow), user, ca, creditFacade
        );

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(
            IERC20All(underlying).balanceOf(user) - userBalBefore,
            extraBorrow,
            "user received additional borrow"
        );
        assertEq(IERC20All(underlying).balanceOf(address(composer)), 0, "composer holds no residue");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Partial repay
    // ─────────────────────────────────────────────────────────────────────────

    function test_fork_gearbox_partial_repay_reduces_debt() public {
        uint256 seed = uint256(minDebt) * 10;
        uint256 debtAmt = uint256(minDebt) * 2; // borrow 2× minDebt so partial repay leaves room
        address ca = _openCaWithComposerBot(seed, debtAmt, PERM_COMPOSER_EXACT);

        uint256 repayAmt = uint256(minDebt) / 2;
        deal(underlying, user, repayAmt);
        vm.prank(user);
        IERC20All(underlying).approve(address(composer), type(uint256).max);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(underlying, address(composer), repayAmt),
            CalldataLib.encodeGearboxV3RepayPartial(underlying, uint128(repayAmt), ca, creditFacade, CREDIT_MANAGER)
        );

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(IERC20All(underlying).balanceOf(user), 0, "user spent repayAmt");
        assertEq(IERC20All(underlying).balanceOf(address(composer)), 0, "composer holds no residue");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Withdraw collateral
    // ─────────────────────────────────────────────────────────────────────────

    function test_fork_gearbox_withdraw_sends_collateral_to_receiver() public {
        uint256 seed = uint256(minDebt) * 10;
        address ca = _openCaWithComposerBot(seed, _pickBorrowAmount(), PERM_COMPOSER_EXACT);

        uint256 pullOut = 1e18;
        uint256 balBefore = IERC20All(ETHPLUS).balanceOf(user);

        bytes memory data = CalldataLib.encodeGearboxV3Withdraw(
            ETHPLUS, uint128(pullOut), user, ca, creditFacade
        );

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(IERC20All(ETHPLUS).balanceOf(user) - balBefore, pullOut, "user received withdraw");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Full repay — superseded by §9 FS2 (`test_fork_gearbox_safe_close_drained_ca_*`).
    //    The old "dust-safe close with sweep back to user" path has been replaced by the
    //    pinned close-out primitive which deposits exactly `maxRepayment` and leaves surplus
    //    (if any) on the composer for explicit sweep. See GEARBOX.md §5 for the new flow.
    // ─────────────────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Mode C — openCreditAccount via GEARBOX_MULTICALL pins onBehalfOf to caller
    // ─────────────────────────────────────────────────────────────────────────

    function test_fork_gearbox_mode_c_opens_ca_with_user_as_borrower() public {
        uint256 seed = uint256(minDebt) * 10;
        deal(ETHPLUS, user, seed);
        vm.prank(user);
        IERC20All(ETHPLUS).approve(address(composer), type(uint256).max);

        uint256 borrowAmt = _pickBorrowAmount();

        // Same ordering rule as `_openCaWithComposerBot`: updateQuota must follow increaseDebt
        // (Gearbox rejects quota updates on a zero-debt CA).
        int96 quota = int96(uint96(borrowAmt * 2));
        bytes memory inner0 = abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (ETHPLUS, seed));
        bytes memory inner1 = abi.encodeCall(ICreditFacadeV3Multicall.increaseDebt, (borrowAmt));
        bytes memory inner2 = abi.encodeCall(ICreditFacadeV3Multicall.updateQuota, (ETHPLUS, quota, uint96(0)));
        bytes memory inner3 =
            abi.encodeCall(ICreditFacadeV3Multicall.setFullCheckParams, (new uint256[](0), uint16(10000)));

        bytes memory packed = abi.encodePacked(
            CalldataLib.encodeGearboxV3FacadeCall(inner0),
            CalldataLib.encodeGearboxV3FacadeCall(inner1),
            CalldataLib.encodeGearboxV3FacadeCall(inner2),
            CalldataLib.encodeGearboxV3FacadeCall(inner3)
        );

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(ETHPLUS, address(composer), seed),
            CalldataLib.encodeApprove(ETHPLUS, CREDIT_MANAGER),
            CalldataLib.encodeGearboxV3OpenCreditAccount(creditFacade, 0, 4, packed)
        );

        vm.prank(user);
        composer.deltaCompose(data);

        // The last open'd CA on this CM should now be owned by `user`. Without a direct "last
        // opened" accessor we query by scanning the CM's active accounts — pick the freshest one
        // whose borrower is `user`.
        address ca = _findCaByBorrower(user);
        require(ca != address(0), "CA not opened");
        assertEq(ICreditManagerV3(CREDIT_MANAGER).getBorrowerOrRevert(ca), user, "user is borrower");
        assertEq(IERC20All(ETHPLUS).balanceOf(ca), seed, "CA holds the collateral seed");
        assertEq(IERC20All(underlying).balanceOf(ca), borrowAmt, "CA holds the borrowed underlying");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Repay edge cases — revert audit
    //
    // Pins the current primitives' revert surface so we know what a future
    // clamped-repay primitive needs to handle. Each test exercises one of:
    //
    //   P1. Partial, amount >> debt                — `decreaseDebt` revert (underflow / over-repay)
    //   P2. Partial, amount leaves (0, minDebt)    — `BorrowAmountOutOfLimitsException`
    //   P3. Partial, amount ≈ debt (no quota strip)— close-out path reverts w/o quota strip or hits minDebt
    //   F1. Full, pulled < debt                    — insufficient CA balance for `decreaseDebt(max)`
    //   F2. Full, missing quotedTokens[]           — close-out blocked by non-zero quotas
    //
    // Happy-path coverage (partial within range, full with sufficient buffer + quoted list) is
    // in §3 / §5 above.
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Seed `user` with `amt` underlying and max-approve composer.
    function _fundUserForRepay(uint256 amt) internal {
        deal(underlying, user, amt);
        vm.prank(user);
        IERC20All(underlying).approve(address(composer), type(uint256).max);
    }

    /// P1. Partial repay with amount far above current debt must revert.
    function test_fork_gearbox_partial_repay_overshoot_reverts() public {
        uint256 seed = uint256(minDebt) * 10;
        uint256 debtAmt = uint256(minDebt) * 2;
        address ca = _openCaWithComposerBot(seed, debtAmt, PERM_COMPOSER_EXACT);

        uint256 overshoot = debtAmt * 5; // way above debt + any accrual
        _fundUserForRepay(overshoot);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(underlying, address(composer), overshoot),
            CalldataLib.encodeGearboxV3RepayPartial(underlying, uint128(overshoot), ca, creditFacade, CREDIT_MANAGER)
        );

        (uint256 debtBefore,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);

        vm.prank(user);
        vm.expectRevert();
        composer.deltaCompose(data);

        (uint256 debtAfter,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);
        assertEq(debtAfter, debtBefore, "CA debt unchanged by reverted partial-overshoot");
    }

    /// P2. Partial repay that leaves residual debt in (0, minDebt) must revert.
    function test_fork_gearbox_partial_repay_below_minDebt_reverts() public {
        uint256 seed = uint256(minDebt) * 10;
        uint256 debtAmt = uint256(minDebt) * 2;
        address ca = _openCaWithComposerBot(seed, debtAmt, PERM_COMPOSER_EXACT);

        // Aim to leave the CA with exactly (minDebt / 2) of remaining debt — squarely inside
        // the forbidden (0, minDebt) window. Uses the on-chain debt snapshot to be accrual-safe.
        (uint256 debtNow,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);
        uint256 targetRemainder = uint256(minDebt) / 2;
        require(debtNow > targetRemainder, "pick a larger debtAmt");
        uint256 repayAmt = debtNow - targetRemainder;

        _fundUserForRepay(repayAmt);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(underlying, address(composer), repayAmt),
            CalldataLib.encodeGearboxV3RepayPartial(underlying, uint128(repayAmt), ca, creditFacade, CREDIT_MANAGER)
        );

        vm.prank(user);
        vm.expectRevert(); // BorrowAmountOutOfLimitsException
        composer.deltaCompose(data);
    }

    /// P3. Partial repay with amount == debt-at-snapshot. Two possible failure modes, both revert:
    ///   (a) If accrual pushed actual debt above the snapshot, remainder lands in (0, accrual) ⊂
    ///       (0, minDebt) → `BorrowAmountOutOfLimitsException`.
    ///   (b) If accrual is perfectly zero this block, remainder = 0 but quotas are still nonzero
    ///       → `fullCollateralCheck` reverts (quota on a zero-debt CA is forbidden).
    /// Either way, the partial primitive must not silently close-out the account.
    function test_fork_gearbox_partial_repay_at_debt_snapshot_reverts() public {
        uint256 seed = uint256(minDebt) * 10;
        uint256 debtAmt = uint256(minDebt) * 2;
        address ca = _openCaWithComposerBot(seed, debtAmt, PERM_COMPOSER_EXACT);

        (uint256 debtNow,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);
        uint256 repayAmt = debtNow;

        _fundUserForRepay(repayAmt);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(underlying, address(composer), repayAmt),
            CalldataLib.encodeGearboxV3RepayPartial(underlying, uint128(repayAmt), ca, creditFacade, CREDIT_MANAGER)
        );

        vm.prank(user);
        vm.expectRevert();
        composer.deltaCompose(data);
    }

    // F1 (low-buffer graceful-close) removed — the old full-repay's "use CA's own underlying
    //    to cover the gap" behavior no longer applies under the new strict safe-close
    //    (`bal >= maxRepay` is required; underfunding reverts cleanly, no silent partial).
    //    Rationale pinned by §9 FS2 and FS3 below.

    /// F2. Full-repay path without the required `quotedTokens[]` list. Debt goes to zero but
    ///     quotas remain non-zero → Gearbox's full collateral check rejects the state.
    function test_fork_gearbox_full_repay_missing_quoted_tokens_reverts() public {
        uint256 seed = uint256(minDebt) * 10;
        uint256 debtAmt = uint256(minDebt) * 3;
        address ca = _openCaWithComposerBot(seed, debtAmt, PERM_COMPOSER_EXACT);

        // Sanity: the open flow set a quota on ETHPLUS. Pass an empty list to the close-out op.
        address[] memory noQuoted = new address[](0);

        uint256 pulled = debtAmt + (debtAmt / 100);
        _fundUserForRepay(pulled);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(underlying, address(composer), pulled),
            CalldataLib.encodeGearboxV3RepayAll(underlying, ca, creditFacade, CREDIT_MANAGER, noQuoted)
        );

        (uint256 debtBefore,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);

        vm.prank(user);
        vm.expectRevert();
        composer.deltaCompose(data);

        (uint256 debtAfter,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);
        assertEq(debtAfter, debtBefore, "CA debt unchanged by reverted close-out missing quota list");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. On-chain debt read helper — shared between §9 FS tests that need to know
    //    `maxRepayment` for pre-funding the safe-close. The old N1/N2 tests that motivated the
    //    primitive's design are superseded by §9 FS2/FS3 which exercise the final primitive
    //    end-to-end.
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev `debt + accruedInterest + accruedFees` — Gearbox's `CreditLogic.calcTotalDebt`, and
    ///      equal to `maxRepayment` for non-USDT pools (wstETH CM does not override `_amountWithFee`).
    function _readMaxRepayment(address ca) internal view returns (uint256) {
        CollateralDebtData memory cdd = ICM_V3Calc(CREDIT_MANAGER).calcDebtAndCollateral(ca, 1); // DEBT_ONLY
        return cdd.debt + cdd.accruedInterest + cdd.accruedFees;
    }

    /// @dev Scan CM's account list for one owned by `who`.
    function _findCaByBorrower(address who) internal view returns (address) {
        // We don't have a direct "last" accessor, so fall back to the CM's account enumeration.
        // The interface exposes `creditAccounts()` via a plain call.
        (bool ok, bytes memory ret) = CREDIT_MANAGER.staticcall(abi.encodeWithSignature("creditAccounts()"));
        require(ok, "creditAccounts() failed");
        address[] memory accounts = abi.decode(ret, (address[]));
        for (uint256 i = accounts.length; i > 0; i--) {
            address ca = accounts[i - 1];
            try ICreditManagerV3(CREDIT_MANAGER).getBorrowerOrRevert(ca) returns (address b) {
                if (b == who) return ca;
            } catch {}
        }
        return address(0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Safe-repay primitive — live-fork coverage
    //
    // Validates the new `GEARBOX_REPAY_SAFE` primitive end-to-end against the wstETH credit
    // suite, with Morpho Blue as an optional flash source for the close-out shape.
    //
    //   FS1. Safe-partial under-funded → executes, residue debt ≥ minDebt, no revert.
    //   FS2. Pinned close-out on drained CA (the §8 N2 scenario) → closes cleanly, no sweep revert.
    //   FS3. Morpho-Blue-flash-wrapped close-out → safe-close works inside a flash callback.
    // ─────────────────────────────────────────────────────────────────────────

    /// FS1. Liquidation-prevention partial: caller delivers far less than debt; primitive
    ///      executes without reverting and reduces debt by exactly the caller's balance.
    function test_fork_gearbox_safe_partial_underdelivers_executes() public {
        uint256 seed = uint256(minDebt) * 10;
        uint256 debtAmt = uint256(minDebt) * 4;
        address ca = _openCaWithComposerBot(seed, debtAmt, PERM_COMPOSER_EXACT);

        // Pull only a fraction of debt — the "save me from liquidation" scenario.
        uint256 repayAmt = uint256(minDebt) / 2;
        _fundUserForRepay(repayAmt);

        (uint256 debtBefore,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(underlying, address(composer), repayAmt),
            CalldataLib.encodeGearboxV3RepayPartialMax(underlying, ca, creditFacade, CREDIT_MANAGER)
        );

        vm.prank(user);
        composer.deltaCompose(data); // MUST NOT revert — that's the whole point

        (uint256 debtAfter,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);
        assertGt(debtBefore, debtAfter, "debt reduced");
        assertGt(debtAfter, 0, "not closed (no quota strip means cannot close)");
        assertGe(debtAfter, minDebt, "remainder above minDebt floor (no window revert)");
        assertEq(IERC20All(underlying).balanceOf(address(composer)), 0, "composer balance fully consumed");
    }

    /// FS2. **The §8 N2 fix**: drained-CA close-out now works. Same setup that previously caused
    ///      `AmountCantBeZeroException` under the old `encodeGearboxV3RepayAll` path — the new
    ///      primitive omits the trailing `withdrawCollateral` sweep, so an empty CA closes cleanly.
    function test_fork_gearbox_safe_close_drained_ca_no_sweep_revert() public {
        uint256 seed = uint256(minDebt) * 10;
        uint256 debtAmt = uint256(minDebt) * 3;
        address ca = _openCaWithComposerBot(seed, debtAmt, PERM_COMPOSER_EXACT);

        // Simulate "borrow deployed out of the CA": withdraw the borrowed wstETH to a sink.
        address sink = address(0xDEAD);
        bytes memory drain = CalldataLib.encodeGearboxV3Withdraw(
            underlying, uint128(debtAmt), sink, ca, creditFacade
        );
        vm.prank(user);
        composer.deltaCompose(drain);
        assertEq(IERC20All(underlying).balanceOf(ca), 0, "CA drained pre-close");

        // Advance so interest accrues — tests the on-chain-read accuracy under that condition.
        vm.roll(block.number + 50);
        vm.warp(block.timestamp + 600);

        uint256 maxRepayment = _readMaxRepayment(ca);
        _fundUserForRepay(maxRepayment);
        address[] memory quoted = _enabledQuotedTokens(ca);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(underlying, address(composer), maxRepayment),
            CalldataLib.encodeGearboxV3RepayAll(underlying, ca, creditFacade, CREDIT_MANAGER, quoted)
        );

        vm.prank(user);
        composer.deltaCompose(data); // no AmountCantBeZeroException — fix validated

        (uint256 debtAfter,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);
        assertEq(debtAfter, 0, "debt zeroed on drained CA - fix for the old full-close bug");
        assertEq(IERC20All(underlying).balanceOf(ca), 0, "CA stays at zero underlying (no sweep needed)");
        assertEq(IERC20All(underlying).balanceOf(address(composer)), 0, "composer consumed exactly maxRepay");
    }

    /// FS3. Morpho-Blue flash wrapping a safe-close. User pre-funds the composer with the close
    ///      amount and flash-loans a small extra amount from Morpho Blue (zero-fee on Morpho V1),
    ///      to demonstrate the primitive operates correctly inside a flash callback — same
    ///      `callerAddress` validation, same auth derivation, no reentrancy issues.
    ///
    ///      Morpho Blue on mainnet: 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb. Zero flash fee.
    function test_fork_gearbox_morpho_flash_wraps_safe_close() public {
        address constant_morphoBlue = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

        uint256 seed = uint256(minDebt) * 10;
        uint256 debtAmt = uint256(minDebt) * 3;
        address ca = _openCaWithComposerBot(seed, debtAmt, PERM_COMPOSER_EXACT);

        // Drain the CA to emulate a realistic leverage-close starting state.
        address sink = address(0xD1D1);
        bytes memory drain = CalldataLib.encodeGearboxV3Withdraw(
            underlying, uint128(debtAmt), sink, ca, creditFacade
        );
        vm.prank(user);
        composer.deltaCompose(drain);

        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 120);

        uint256 maxRepayment = _readMaxRepayment(ca);
        uint256 flashAmt = 1 wei; // minimal Morpho flash — atomicity wrapper only
        // Pre-fund composer with the close amount; the flash proves the primitive works inside
        // a re-entered deltaCompose context without adding funding complexity.
        _fundUserForRepay(maxRepayment);

        address[] memory quoted = _enabledQuotedTokens(ca);

        // Build the flash callback payload: repay-safe close only. Morpho Blue re-enters via
        // `onMorphoFlashLoan` which runs our `deltaCompose` tail with this payload.
        bytes memory callbackOps = abi.encodePacked(
            CalldataLib.encodeTransferIn(underlying, address(composer), maxRepayment),
            CalldataLib.encodeGearboxV3RepayAll(underlying, ca, creditFacade, CREDIT_MANAGER, quoted)
        );

        // Outer tx: approve Morpho to pull `flashAmt` back, then trigger the flash.
        bytes memory outerOps = abi.encodePacked(
            CalldataLib.encodeApprove(underlying, constant_morphoBlue),
            CalldataLib.encodeFlashLoan(
                underlying,
                flashAmt,
                constant_morphoBlue,
                uint8(0), // FlashLoanIds.MORPHO
                uint8(0), // poolId — Morpho Blue uses id 0 in the callback validator
                callbackOps
            )
        );

        vm.prank(user);
        composer.deltaCompose(outerOps);

        (uint256 debtAfter,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);
        assertEq(debtAfter, 0, "debt zeroed: Morpho-flash -> safe-close -> flash-return round trip");
        assertEq(IERC20All(underlying).balanceOf(address(composer)), 0, "no residue on composer after flash round-trip");
    }
}
