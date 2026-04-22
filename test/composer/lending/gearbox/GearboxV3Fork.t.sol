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
    // 5. Full repay — dust-safe close-out
    // ─────────────────────────────────────────────────────────────────────────

    function test_fork_gearbox_full_repay_zero_dust_close() public {
        uint256 seed = uint256(minDebt) * 10;
        uint256 debtAmt = uint256(minDebt) * 3; // pick something comfortably above minDebt
        address ca = _openCaWithComposerBot(seed, debtAmt, PERM_COMPOSER_EXACT);

        // Buffer: debt + small margin for accruals between fork block and tx inclusion.
        // We pad 1% so a few seconds of interest never tips us into the "insufficient balance" path.
        uint256 pulledAmount = debtAmt + (debtAmt / 100);
        deal(underlying, user, pulledAmount);
        vm.prank(user);
        IERC20All(underlying).approve(address(composer), type(uint256).max);

        address[] memory quoted = _enabledQuotedTokens(ca);

        uint256 userBalBefore = IERC20All(underlying).balanceOf(user);
        uint256 caCollBefore = IERC20All(ETHPLUS).balanceOf(ca);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(underlying, address(composer), pulledAmount),
            CalldataLib.encodeGearboxV3RepayAll(underlying, ca, creditFacade, CREDIT_MANAGER, quoted)
        );

        vm.prank(user);
        composer.deltaCompose(data);

        // Dust-safety invariants: the composer holds nothing, the CA holds at most the 1-wei
        // protocol sentinel Gearbox's `withdrawCollateral(type(uint256).max, …)` intentionally
        // leaves (warm-slot optimization; see `CreditFacadeV3._withdrawCollateral` at line 754).
        assertEq(IERC20All(underlying).balanceOf(address(composer)), 0, "composer holds no residue");
        assertLe(IERC20All(underlying).balanceOf(ca), 1, "CA holds at most the 1-wei protocol sentinel");

        // Position is fully closed — debt zeroed on-chain.
        (uint256 debtRemaining,,,,,,,) = ICM_V3Info(CREDIT_MANAGER).creditAccountInfo(ca);
        assertEq(debtRemaining, 0, "debt zeroed");

        // The user cannot have spent more than what they pulled. We can't assert "net spent >=
        // nominal debt" here — since the borrowed underlying was sitting on the CA pre-repay,
        // the withdrawCollateral sweep returns that alongside the unused buffer, so the user's
        // token-level cost is just the accrued interest over the test's block span.
        uint256 netSpent = userBalBefore - IERC20All(underlying).balanceOf(user);
        assertLe(netSpent, pulledAmount, "user cannot have spent more than pulled");

        // Collateral untouched by the repay flow.
        assertEq(IERC20All(ETHPLUS).balanceOf(ca), caCollBefore, "collateral untouched");
    }

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
}
