// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MidnightMock, Market, CollateralParams, Offer, IMidnightFlashLoanReceiver} from "./MidnightMock.sol";

/**
 * @notice Unit coverage for the composer's Morpho Midnight primitives against a mock singleton.
 * @dev No fork — the mock reproduces the exact selectors + token flows and records decoded args so we
 *      can assert selector binding, `onBehalf`/`taker` pinning, amount injection, arg relay, and the
 *      flash-loan round-trip. Midnight is deployed on Base, so the callback's hardcoded instance address
 *      is `etch`-ed with the mock to satisfy the `caller() == MIDNIGHT` check. A live Base fork test with
 *      real signed offers should be layered on top once market/offer infra is available off-chain.
 */
contract MidnightLendingMockTest is BaseTest {
    IComposerLike internal composer;
    MidnightMock internal midnight;

    /// @dev Canonical Base Midnight instance (matches the generated MidnightCallback constant).
    address internal constant MIDNIGHT = 0xAdedD8ab6dE832766Fedf0FaC4992E5C4D3EA18A;

    MockERC20 internal loan; // loan token
    MockERC20 internal coll; // collateral token

    address internal constant PLACEHOLDER = address(0xBAD); // stand-in for pinned/injected fields
    address internal constant CB_PLACEHOLDER = address(0xCAFE); // stand-in for a callback field

    function setUp() public {
        _init(Chains.BASE, 0, false);
        composer = ComposerPlugin.getComposer(Chains.BASE);

        // Put the mock at the canonical Midnight address so the flash-loan callback caller check passes.
        MidnightMock impl = new MidnightMock();
        vm.etch(MIDNIGHT, address(impl).code);
        midnight = MidnightMock(MIDNIGHT);

        loan = new MockERC20("LoanUSD", "lUSD", 6);
        coll = new MockERC20("CollBTC", "cBTC", 8);

        vm.label(address(composer), "Composer");
        vm.label(MIDNIGHT, "MidnightMock");
        vm.label(address(loan), "lUSD");
        vm.label(address(coll), "cBTC");
    }

    // ─────────────────────────────── helpers ───────────────────────────────

    function _market() internal view returns (Market memory m) {
        CollateralParams[] memory cps = new CollateralParams[](1);
        cps[0] = CollateralParams({token: address(coll), lltv: 0.8e18, liquidationCursor: 0.3e18, oracle: address(0xDEAD)});
        m = Market({
            chainId: block.chainid,
            midnight: MIDNIGHT,
            loanToken: address(loan),
            collateralParams: cps,
            maturity: block.timestamp + 30 days,
            rcfThreshold: 0,
            enterGate: address(0),
            liquidatorGate: address(0)
        });
    }

    function _offer(bool buy) internal view returns (Offer memory o) {
        o.market = _market();
        o.buy = buy;
        o.maker = address(0xA11CE);
        o.start = 0;
        o.expiry = block.timestamp + 1 days;
        o.tick = 4;
        o.ratifier = address(0xBEEF);
    }

    function _prime(MockERC20 tok, uint256 amt) internal {
        tok.mint(user, amt);
        vm.prank(user);
        tok.approve(address(composer), type(uint256).max);
    }

    function _transferIn(MockERC20 tok, uint256 amt) internal view returns (bytes memory) {
        return CalldataLib.encodeTransferIn(address(tok), address(composer), amt);
    }

    // ─────────────────────── 1. supplyCollateral (DEPOSIT) ───────────────────────

    function test_midnight_supplyCollateral_explicit_amount_relays_onBehalf() public {
        _prime(coll, 5e8);

        // supply is a benign inflow: onBehalf is caller-parameterized (Morpho Blue convention), NOT
        // pinned to the caller — you can credit collateral to any position.
        address beneficiary = address(0xB0B);
        bytes memory args = abi.encode(
            _market(),
            uint256(0),
            uint256(999),
            /*assets placeholder*/
            beneficiary
        );
        bytes memory op = CalldataLib.encodeMidnightSupplyCollateral(MIDNIGHT, address(coll), 3e8, args);

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(_transferIn(coll, 3e8), op));

        assertEq(midnight.lastFn(), "supplyCollateral");
        assertEq(midnight.lastCollateralIndex(), 0);
        assertEq(midnight.lastAssets(), 3e8, "assets injected from header amount");
        assertEq(midnight.lastOnBehalf(), beneficiary, "onBehalf relayed verbatim (not pinned to caller)");
        assertTrue(beneficiary != user, "sanity: beneficiary differs from caller");
        assertEq(midnight.lastCollateralToken(), address(coll));
        assertEq(coll.balanceOf(MIDNIGHT), 3e8, "collateral pulled into midnight");
        assertEq(coll.balanceOf(address(composer)), 0, "no residue on composer");
    }

    function test_midnight_supplyCollateral_zero_amount_uses_composer_balance() public {
        _prime(coll, 4e8);

        address beneficiary = address(0xB0B);
        bytes memory args = abi.encode(_market(), uint256(0), uint256(0), beneficiary);
        // amount 0 => the composer supplies its full collateral balance
        bytes memory op = CalldataLib.encodeMidnightSupplyCollateral(MIDNIGHT, address(coll), 0, args);

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(_transferIn(coll, 4e8), op));

        assertEq(midnight.lastAssets(), 4e8, "assets resolved to composer balance");
        assertEq(midnight.lastOnBehalf(), beneficiary, "onBehalf relayed verbatim");
        assertEq(coll.balanceOf(MIDNIGHT), 4e8);
    }

    // ─────────────────────── 2. withdrawCollateral (WITHDRAW) ───────────────────────

    function test_midnight_withdrawCollateral_pins_onBehalf_relays_receiver() public {
        coll.mint(MIDNIGHT, 2e8); // midnight holds the collateral it will return

        bytes memory args = abi.encode(
            _market(),
            uint256(0),
            uint256(5e7),
            /*assets, not injected*/
            PLACEHOLDER,
            user
        );
        bytes memory op = CalldataLib.encodeMidnightWithdrawCollateral(MIDNIGHT, args);

        vm.prank(user);
        composer.deltaCompose(op);

        assertEq(midnight.lastFn(), "withdrawCollateral");
        assertEq(midnight.lastAssets(), 5e7, "assets relayed verbatim");
        assertEq(midnight.lastOnBehalf(), user, "onBehalf pinned to caller");
        assertEq(midnight.lastReceiver(), user, "receiver relayed verbatim");
        assertEq(coll.balanceOf(user), 5e7, "user received withdrawn collateral");
    }

    // ─────────────────────── 3. repay (REPAY) ───────────────────────

    function test_midnight_repay_injects_units_relays_onBehalf_forces_no_callback() public {
        _prime(loan, 500e6);

        // onBehalf is a third-party debtor: repay is benign, so the composer does NOT pin it to the caller.
        address debtor = address(0xB0B);
        bytes memory args = abi.encode(_market(), uint256(777) /*units placeholder*/, debtor, CB_PLACEHOLDER, bytes(""));
        bytes memory op = CalldataLib.encodeMidnightRepay(MIDNIGHT, address(loan), 200e6, args);

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(_transferIn(loan, 200e6), op));

        assertEq(midnight.lastFn(), "repay");
        assertEq(midnight.lastUnits(), 200e6, "units injected from header amount");
        assertEq(midnight.lastOnBehalf(), debtor, "onBehalf relayed verbatim (not pinned to caller)");
        assertTrue(debtor != user, "sanity: debtor differs from caller");
        assertEq(midnight.lastTakerCallback(), address(0), "repay callback forced to zero (composer pays)");
        assertEq(loan.balanceOf(MIDNIGHT), 200e6, "loan token pulled from composer");
        assertEq(loan.balanceOf(address(composer)), 0);
    }

    function test_midnight_repay_zero_amount_uses_composer_balance() public {
        _prime(loan, 321e6);

        bytes memory args = abi.encode(_market(), uint256(0), user /*onBehalf*/, CB_PLACEHOLDER, bytes(""));
        bytes memory op = CalldataLib.encodeMidnightRepay(MIDNIGHT, address(loan), 0, args);

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(_transferIn(loan, 321e6), op));

        assertEq(midnight.lastUnits(), 321e6, "units resolved to composer balance");
        assertEq(midnight.lastOnBehalf(), user, "onBehalf relayed verbatim");
        assertEq(loan.balanceOf(MIDNIGHT), 321e6);
    }

    // ─────────────────────── 4. withdraw credit (WITHDRAW_LENDING_TOKEN) ───────────────────────

    function test_midnight_withdraw_credit_pins_onBehalf_relays_receiver() public {
        loan.mint(MIDNIGHT, 100e6); // midnight holds the loan token to redeem

        bytes memory args = abi.encode(
            _market(),
            uint256(50e6),
            /*units, not injected*/
            PLACEHOLDER,
            user
        );
        bytes memory op = CalldataLib.encodeMidnightWithdraw(MIDNIGHT, args);

        vm.prank(user);
        composer.deltaCompose(op);

        assertEq(midnight.lastFn(), "withdraw");
        assertEq(midnight.lastUnits(), 50e6, "units relayed verbatim");
        assertEq(midnight.lastOnBehalf(), user, "onBehalf pinned to caller");
        assertEq(midnight.lastReceiver(), user);
        assertEq(loan.balanceOf(user), 50e6, "user redeemed credit for loan token");
    }

    // ─────────────────────── 5. take (MIDNIGHT_TAKE) ───────────────────────

    function test_midnight_take_borrow_pins_taker_forces_no_callback() public {
        loan.mint(MIDNIGHT, 1_000e6); // midnight funds the borrow proceeds

        // offer.buy == true => taker is the borrower/seller and receives sellerAssets at `receiver`
        bytes memory args = abi.encode(
            _offer(true),
            bytes(""), // ratifierData
            uint256(100e6), // units
            PLACEHOLDER, // taker placeholder -> pinned
            user, // receiverIfTakerIsSeller
            CB_PLACEHOLDER, // takerCallback placeholder -> forced 0
            bytes("") // takerCallbackData
        );
        bytes memory op = CalldataLib.encodeMidnightTake(MIDNIGHT, args);

        vm.prank(user);
        composer.deltaCompose(op);

        assertEq(midnight.lastFn(), "take");
        assertTrue(midnight.lastBuy(), "offer.buy relayed");
        assertEq(midnight.lastUnits(), 100e6);
        assertEq(midnight.lastTaker(), user, "taker pinned to caller (placeholder overwritten)");
        assertEq(midnight.lastTakerCallback(), address(0), "takerCallback forced to zero");
        assertEq(midnight.lastReceiver(), user, "receiver relayed verbatim");
        assertEq(loan.balanceOf(user), 100e6, "borrow proceeds delivered to receiver");
    }

    function test_midnight_take_lend_composer_pays() public {
        _prime(loan, 250e6);

        // offer.buy == false => taker is the buyer/lender; the composer (payer) funds buyerAssets
        bytes memory args = abi.encode(
            _offer(false),
            bytes(""),
            uint256(250e6),
            PLACEHOLDER,
            address(0),
            /*unused receiver*/
            CB_PLACEHOLDER,
            bytes("")
        );
        bytes memory op = CalldataLib.encodeMidnightTake(MIDNIGHT, args);

        // lending side pays from the composer -> Midnight must be approved for the loan token
        bytes memory approve = CalldataLib.encodeApprove(address(loan), MIDNIGHT);

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(_transferIn(loan, 250e6), approve, op));

        assertEq(midnight.lastFn(), "take");
        assertFalse(midnight.lastBuy());
        assertEq(midnight.lastTaker(), user, "taker pinned to caller");
        assertEq(midnight.lastTakerCallback(), address(0));
        assertEq(loan.balanceOf(MIDNIGHT), 250e6, "composer paid for the credit");
        assertEq(loan.balanceOf(address(composer)), 0);
    }

    // ─────────────────────── 6. flash loan (FlashLoanIds.MORPHO_MIDNIGHT) ───────────────────────

    function test_midnight_flashLoan_single_token_roundtrip() public {
        loan.mint(MIDNIGHT, 10_000e6); // liquidity to lend

        // inner compose op runs inside the callback (balance-neutral here); repayment is handled by the
        // approval the encoder prepends, and the borrowed amount stays on the composer to be pulled back.
        bytes memory inner = CalldataLib.encodeApprove(address(coll), address(0xDEAD));
        // single-asset convenience variant (same call shape as Morpho/Aave `encodeFlashLoan`)
        bytes memory op = CalldataLib.encodeMidnightFlashLoan(address(loan), 1_000e6, MIDNIGHT, 0, inner);

        // must be byte-identical to the explicit 1-element multi-token form
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(loan);
        amounts[0] = 1_000e6;
        assertEq(op, CalldataLib.encodeMidnightFlashLoan(MIDNIGHT, tokens, amounts, 0, inner), "single-asset == multi-token(1)");

        vm.prank(user);
        composer.deltaCompose(op);

        assertTrue(midnight.flashLoanCalled(), "flashLoan invoked");
        assertEq(midnight.lastFlashInitiator(), address(composer), "callback target is the composer");
        assertEq(midnight.lastFlashTokenCount(), 1);
        assertEq(midnight.lastFlashToken0(), address(loan));
        assertEq(midnight.lastFlashAmount0(), 1_000e6);
        assertEq(loan.balanceOf(MIDNIGHT), 10_000e6, "principal returned in full");
        assertEq(loan.balanceOf(address(composer)), 0, "no residue on composer");
    }

    function test_midnight_flashLoan_multi_token_roundtrip() public {
        loan.mint(MIDNIGHT, 5_000e6);
        coll.mint(MIDNIGHT, 5e8);

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(loan);
        amounts[0] = 1_000e6;
        tokens[1] = address(coll);
        amounts[1] = 2e8;

        bytes memory inner = CalldataLib.encodeApprove(address(loan), address(0xDEAD));
        bytes memory op = CalldataLib.encodeMidnightFlashLoan(MIDNIGHT, tokens, amounts, 0, inner);

        vm.prank(user);
        composer.deltaCompose(op);

        assertTrue(midnight.flashLoanCalled());
        assertEq(midnight.lastFlashTokenCount(), 2, "both tokens forwarded");
        assertEq(midnight.lastFlashToken0(), address(loan));
        assertEq(midnight.lastFlashAmount0(), 1_000e6);
        assertEq(loan.balanceOf(MIDNIGHT), 5_000e6, "loan principal returned");
        assertEq(coll.balanceOf(MIDNIGHT), 5e8, "collateral principal returned");
    }

    /// @notice The flash-loan callback must reject any caller that is not the canonical Midnight instance.
    function test_midnight_flashLoan_callback_rejects_foreign_caller() public {
        address[] memory empty = new address[](0);
        uint256[] memory emptyAmts = new uint256[](0);
        // data = origCaller(20) | poolId(1 == 0): reaches the caller check, which fails (caller != MIDNIGHT)
        bytes memory data = abi.encodePacked(user, uint8(0));

        vm.expectRevert();
        IMidnightFlashLoanReceiver(address(composer)).onFlashLoan(address(this), empty, emptyAmts, data);
    }

    /// @notice A non-zero poolId (no fork configured) is rejected even from the canonical instance.
    function test_midnight_flashLoan_callback_rejects_unknown_poolId() public {
        address[] memory empty = new address[](0);
        uint256[] memory emptyAmts = new uint256[](0);
        bytes memory data = abi.encodePacked(user, uint8(1)); // poolId 1 => INVALID_FLASH_LOAN

        vm.prank(MIDNIGHT);
        vm.expectRevert();
        IMidnightFlashLoanReceiver(address(composer)).onFlashLoan(MIDNIGHT, empty, emptyAmts, data);
    }

    /// @notice The callback must reject a valid Midnight caller that did NOT self-initiate the loan.
    /// @dev Midnight lets the caller pick the callback target, so an attacker can invoke Midnight
    ///      directly with `callback = composer` and a spoofed `origCaller`, which passes the
    ///      `caller() == MIDNIGHT` check. The `initiator == address(this)` check is what blocks the
    ///      impersonation: here `caller()` is Midnight and `poolId` is 0 (both valid), but the
    ///      initiator is the attacker rather than the composer, so the callback must revert.
    function test_midnight_flashLoan_callback_rejects_foreign_initiator() public {
        address attacker = address(0xBAD);
        address[] memory empty = new address[](0);
        uint256[] memory emptyAmts = new uint256[](0);
        // poolId 0 (valid) + spoofed origCaller = victim `user`; only the initiator is wrong.
        bytes memory data = abi.encodePacked(user, uint8(0));

        // Assert the SPECIFIC InvalidInitiator selector (0xbfda1f28). This is load-bearing: without the
        // initiator check the call would fall through to `_deltaComposeInternal` and revert (or worse,
        // succeed) with a different reason, so a generic `expectRevert()` would pass even when vulnerable.
        vm.prank(MIDNIGHT);
        vm.expectRevert(bytes4(0xbfda1f28)); // INVALID_INITIATOR
        IMidnightFlashLoanReceiver(address(composer)).onFlashLoan(attacker, empty, emptyAmts, data);
    }
}
