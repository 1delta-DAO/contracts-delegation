// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {GearboxV3FacadeMock} from "./GearboxV3Mock.sol";

/**
 * @notice Unit coverage for the composer's Gearbox V3 primitives against a mock facade.
 * @dev No fork — the mock captures every MultiCall[] the composer emits, lets us assert
 *      selectors, args, and fund-flow. A live mainnet fork test should be layered on top
 *      once a stable Gearbox credit-suite address is pinned.
 */
contract GearboxV3LendingMockTest is BaseTest {
    IComposerLike internal composer;

    GearboxV3FacadeMock internal facade;
    /// @dev In the mock setup the facade plays both the facade and the credit-manager role
    ///      (addCollateral's `transferFrom` happens from the address that called the facade).
    ///      Production has two separate contracts — that's a live-fork concern, not a unit test.
    address internal creditManager;
    address internal creditAccount = address(0xCAcA);

    MockERC20 internal underlying;
    MockERC20 internal collToken;

    bytes4 internal constant SEL_ADD_COLLATERAL = 0x6d75b9ee;
    bytes4 internal constant SEL_INCREASE_DEBT = 0x2b7c7b11;
    bytes4 internal constant SEL_DECREASE_DEBT = 0x2a7ba1f7;
    bytes4 internal constant SEL_WITHDRAW_COLLATERAL = 0x1f1088a0;
    bytes4 internal constant SEL_SET_FULL_CHECK = 0x0768bbfe;
    bytes4 internal constant SEL_UPDATE_QUOTA = 0x712c10ad;

    function setUp() public {
        // No fork — deploy the local mock stack. Composer is Ethereum-flavored but it doesn't
        // touch chain-specific addresses for the Gearbox primitives.
        _init(Chains.ETHEREUM_MAINNET, 0, false);
        composer = ComposerPlugin.getComposer(Chains.ETHEREUM_MAINNET);

        facade = new GearboxV3FacadeMock(address(0), creditAccount);
        creditManager = address(facade);
        // Default borrower for every CA in the mock is `user` — the composer's auth check will
        // pass when `user` is the msg.sender of `deltaCompose`.
        facade.setBorrower(user);
        underlying = new MockERC20("UnderlyingUSD", "uUSD", 6);
        collToken = new MockERC20("CollatBTC", "cBTC", 8);
        facade.setMockUnderlying(address(underlying));

        vm.label(address(composer), "Composer");
        vm.label(address(facade), "GearboxFacadeMock");
        vm.label(address(underlying), "uUSD");
        vm.label(address(collToken), "cBTC");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    function _prime(MockERC20 tok, address who, uint256 amt) internal {
        tok.mint(who, amt);
        vm.prank(who);
        tok.approve(address(composer), type(uint256).max);
    }

    function _fundPoolLiquidity(uint256 amt) internal {
        // Put underlying on the mock facade so the CA can "borrow" from it via increaseDebt.
        underlying.mint(address(facade), amt);
    }

    function _transferInOp(MockERC20 tok, uint256 amt) internal view returns (bytes memory) {
        return CalldataLib.encodeTransferIn(address(tok), address(composer), amt);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Supply / DEPOSIT
    // ─────────────────────────────────────────────────────────────────────────

    function test_gearboxV3_supply_emits_addCollateral_and_setFullCheck() public {
        _prime(collToken, user, 5e8);

        bytes memory transferIn = _transferInOp(collToken, 3e8);
        bytes memory supply = CalldataLib.encodeGearboxV3Supply(
            address(collToken),
            3e8,
            creditAccount,
            address(facade),
            creditManager,
            11000 // minHF = 1.1
        );

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(transferIn, supply));

        assertFalse(facade.lastKindOpen(), "kind must be botMulticall");
        assertEq(facade.lastCaller(), address(composer), "facade called by composer");
        assertEq(facade.lastCa(), creditAccount, "ca arg matches");
        assertEq(facade.lastCallsLength(), 2, "two sub-calls (addCollateral + setFullCheck)");

        (address t0, bytes memory cd0) = facade.getLastCall(0);
        assertEq(t0, address(facade), "sub-call target must be facade");
        assertEq(bytes4(cd0), SEL_ADD_COLLATERAL, "first sub-call is addCollateral");
        (address tok, uint256 amt) = abi.decode(_sliceCalldata(cd0), (address, uint256));
        assertEq(tok, address(collToken));
        assertEq(amt, 3e8);

        (, bytes memory cd1) = facade.getLastCall(1);
        assertEq(bytes4(cd1), SEL_SET_FULL_CHECK, "second sub-call is setFullCheckParams");
        (uint256[] memory hints, uint16 minHF) = abi.decode(_sliceCalldata(cd1), (uint256[], uint16));
        assertEq(hints.length, 0, "empty hints");
        assertEq(minHF, 11000, "minHF forwarded");

        // Balance should have landed on the CA escrow in the mock.
        assertEq(facade.caBalances(address(collToken)), 3e8, "CA holds 3e8 of collateral");
        assertEq(collToken.balanceOf(address(composer)), 0, "composer holds no residue");
    }

    function test_gearboxV3_supply_minHF_zero_skips_setFullCheck() public {
        _prime(collToken, user, 2e8);

        bytes memory data = abi.encodePacked(
            _transferInOp(collToken, 1e8),
            CalldataLib.encodeGearboxV3Supply(address(collToken), 1e8, creditAccount, address(facade), creditManager, 0)
        );

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(facade.lastCallsLength(), 1, "only addCollateral, no HF check when minHF=0");
        (, bytes memory cd0) = facade.getLastCall(0);
        assertEq(bytes4(cd0), SEL_ADD_COLLATERAL);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Borrow
    // ─────────────────────────────────────────────────────────────────────────

    function test_gearboxV3_borrow_emits_increaseDebt_withdraw_setFullCheck() public {
        _fundPoolLiquidity(10_000e6);

        // Put some collateral on the CA so the "health check" is plausible (mock doesn't enforce
        // HF, but we match realistic flow).
        facade.setMockUnderlying(address(underlying));

        bytes memory borrow = CalldataLib.encodeGearboxV3Borrow(
            address(underlying),
            1_000e6,
            user, // receiver
            creditAccount,
            address(facade),
            creditManager,
            10500
        );

        vm.prank(user);
        composer.deltaCompose(borrow);

        assertFalse(facade.lastKindOpen());
        assertEq(facade.lastCa(), creditAccount);
        assertEq(facade.lastCallsLength(), 3, "3 sub-calls: increaseDebt, withdrawCollateral, setFullCheck");

        (, bytes memory cd0) = facade.getLastCall(0);
        assertEq(bytes4(cd0), SEL_INCREASE_DEBT);
        uint256 incAmt = abi.decode(_sliceCalldata(cd0), (uint256));
        assertEq(incAmt, 1_000e6);

        (, bytes memory cd1) = facade.getLastCall(1);
        assertEq(bytes4(cd1), SEL_WITHDRAW_COLLATERAL);
        (address tok, uint256 wAmt, address to) = abi.decode(_sliceCalldata(cd1), (address, uint256, address));
        assertEq(tok, address(underlying));
        assertEq(wAmt, 1_000e6);
        assertEq(to, user);

        (, bytes memory cd2) = facade.getLastCall(2);
        assertEq(bytes4(cd2), SEL_SET_FULL_CHECK);
        (, uint16 minHF) = abi.decode(_sliceCalldata(cd2), (uint256[], uint16));
        assertEq(minHF, 10500);

        // User received the borrowed underlying, facade (pool liquidity) sent it.
        assertEq(underlying.balanceOf(user), 1_000e6, "user received borrowed amount");
        assertEq(facade.debt(), 1_000e6, "debt tracked");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Withdraw
    // ─────────────────────────────────────────────────────────────────────────

    function test_gearboxV3_withdraw_partial_and_full() public {
        // Seed: 2e8 of collateral on CA directly (skip the addCollateral round trip).
        collToken.mint(address(facade), 2e8);
        _seedCaEscrow(address(collToken), 2e8);

        // Partial withdraw
        bytes memory withdraw = CalldataLib.encodeGearboxV3Withdraw(
            address(collToken), 5e7, user, creditAccount, address(facade), creditManager, 10500
        );
        vm.prank(user);
        composer.deltaCompose(withdraw);
        assertEq(collToken.balanceOf(user), 5e7, "user received partial withdraw");

        // Full withdraw via UINT112_MASK → Gearbox's uint256.max sentinel
        bytes memory wAll = CalldataLib.encodeGearboxV3Withdraw(
            address(collToken), CalldataLib.GEARBOX_WITHDRAW_ALL, user, creditAccount, address(facade), creditManager, 10500
        );
        vm.prank(user);
        composer.deltaCompose(wAll);

        (, bytes memory cd0) = facade.getLastCall(0);
        (, uint256 wAmt,) = abi.decode(_sliceCalldata(cd0), (address, uint256, address));
        assertEq(wAmt, type(uint256).max, "full-withdraw sentinel forwarded as uint256.max");
        assertEq(collToken.balanceOf(user), 2e8, "full withdraw sent entire CA balance");
        assertEq(facade.caBalances(address(collToken)), 0, "CA drained");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Partial repay
    // ─────────────────────────────────────────────────────────────────────────

    function test_gearboxV3_repay_partial_emits_addCollateral_and_decreaseDebt() public {
        // Set up: CA has 500e6 debt; user repays 200e6.
        _fundPoolLiquidity(500e6);
        _seedDebt(500e6);
        _prime(underlying, user, 300e6);

        bytes memory data = abi.encodePacked(
            _transferInOp(underlying, 200e6),
            CalldataLib.encodeGearboxV3RepayPartial(
                address(underlying), 200e6, creditAccount, address(facade), creditManager
            )
        );

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(facade.lastCallsLength(), 2, "addCollateral + decreaseDebt");
        (, bytes memory cd0) = facade.getLastCall(0);
        assertEq(bytes4(cd0), SEL_ADD_COLLATERAL);
        (, bytes memory cd1) = facade.getLastCall(1);
        assertEq(bytes4(cd1), SEL_DECREASE_DEBT);
        uint256 decAmt = abi.decode(_sliceCalldata(cd1), (uint256));
        assertEq(decAmt, 200e6, "partial repay forwards exact amount");

        assertEq(facade.debt(), 300e6, "debt reduced by 200e6");
        assertEq(underlying.balanceOf(address(composer)), 0, "composer holds no residue");
    }

    /// @notice Non-owner caller invoking `deltaCompose` with someone else's CA must revert.
    /// @dev Without this guard, any user who has granted the composer bot permissions would have
    ///      their CA drainable by any caller who knows the CA address.
    function test_gearboxV3_unauthorized_caller_cannot_drain_ca() public {
        _fundPoolLiquidity(10_000e6);

        // CA is owned by `user` in the mock (facade.setBorrower(user) in setUp).
        // `mallory` is a fresh address, not the borrower.
        address mallory = address(0xbADbAd);
        vm.label(mallory, "mallory");
        vm.deal(mallory, 1 ether);

        // Mallory tries to borrow from user's CA and send the proceeds to herself.
        bytes memory borrow = CalldataLib.encodeGearboxV3Borrow(
            address(underlying),
            1_000e6,
            mallory, // receiver
            creditAccount,
            address(facade),
            creditManager,
            10500
        );

        vm.prank(mallory);
        vm.expectRevert();
        composer.deltaCompose(borrow);

        // Sanity: same call from the real owner succeeds (auth is the ONLY difference).
        vm.prank(user);
        composer.deltaCompose(
            CalldataLib.encodeGearboxV3Borrow(
                address(underlying), 1_000e6, user, creditAccount, address(facade), creditManager, 10500
            )
        );
        assertEq(underlying.balanceOf(user), 1_000e6, "owner can borrow");
        assertEq(underlying.balanceOf(mallory), 0, "non-owner attempt took no funds");
    }

    /// @notice Non-owner caller invoking `GEARBOX_MULTICALL` (kind=botMulticall) must revert.
    function test_gearboxV3_unauthorized_caller_cannot_use_generic_bot_multicall() public {
        address mallory = address(0xbADbAd);
        bytes memory inner =
            abi.encodeWithSelector(SEL_WITHDRAW_COLLATERAL, address(collToken), uint256(1e8), mallory);

        bytes memory packed = CalldataLib.encodeGearboxV3FacadeCall(inner);
        bytes memory data = CalldataLib.encodeGearboxV3BotMulticall(
            address(facade), creditAccount, creditManager, 1, packed
        );

        vm.prank(mallory);
        vm.expectRevert();
        composer.deltaCompose(data);
    }

    function test_gearboxV3_repay_partial_amount_zero_reverts() public {
        _prime(underlying, user, 100e6);

        bytes memory data = abi.encodePacked(
            _transferInOp(underlying, 100e6),
            CalldataLib.encodeGearboxV3RepayPartial(
                address(underlying),
                1, // encoder minimum; then we patch to 0 below
                creditAccount,
                address(facade),
                creditManager
            )
        );
        // Patch the amount byte to 0 (offset: transferIn(56) + approve(42) + lendingHeader(3) + underlying(20) = 121)
        // actually: encodeTransferIn is 56 bytes, encodeApprove is 1+1+20+20 = 42 bytes, lending header is 3,
        // underlying is 20 → amount starts at byte 56+42+3+20 = 121. Amount is 16 bytes.
        for (uint256 i = 121; i < 121 + 16; i++) {
            data[i] = 0x00;
        }

        vm.prank(user);
        vm.expectRevert();
        composer.deltaCompose(data);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Full repay — the dust-safe path
    // ─────────────────────────────────────────────────────────────────────────

    function test_gearboxV3_repay_all_emits_strip_quotas_add_decrease_max_withdraw_residue() public {
        // CA has 500e6 debt and 2 active quoted tokens; user pulls 520e6 (4% buffer).
        _fundPoolLiquidity(500e6);
        _seedDebt(500e6);
        _prime(underlying, user, 520e6);

        address[] memory quoted = new address[](2);
        quoted[0] = address(collToken);
        quoted[1] = address(0xDe); // second dummy quoted token

        bytes memory data = abi.encodePacked(
            _transferInOp(underlying, 520e6),
            CalldataLib.encodeGearboxV3RepayAll(
                address(underlying), creditAccount, address(facade), creditManager, quoted
            )
        );

        uint256 userBalBefore = underlying.balanceOf(user);

        vm.prank(user);
        composer.deltaCompose(data);

        _assertRepayAllSequence(quoted, 520e6);

        // Dust assertions
        assertEq(facade.debt(), 0, "debt zeroed");
        assertEq(facade.caBalances(address(underlying)), 0, "no residue on CA");
        assertEq(underlying.balanceOf(address(composer)), 0, "no residue on composer");
        assertEq(userBalBefore - underlying.balanceOf(user), 500e6, "user net spent = exact debt");
    }

    /// @dev Moves the per-sub-call selector/arg assertions out of the test body so the test
    ///      function's stack stays under the solc limit.
    function _assertRepayAllSequence(address[] memory quoted, uint256 pulledAmount) private view {
        assertEq(facade.lastCallsLength(), quoted.length + 3, "updateQuota x N + add + dec + withdraw");

        for (uint256 i = 0; i < quoted.length; i++) {
            (, bytes memory cd) = facade.getLastCall(i);
            assertEq(bytes4(cd), SEL_UPDATE_QUOTA);
            (address tok, int96 qc,) = abi.decode(_sliceCalldata(cd), (address, int96, uint96));
            assertEq(tok, quoted[i]);
            assertEq(qc, type(int96).min, "quotaChange = int96.min");
        }

        {
            (, bytes memory cd) = facade.getLastCall(quoted.length);
            assertEq(bytes4(cd), SEL_ADD_COLLATERAL);
            (address tok, uint256 amt) = abi.decode(_sliceCalldata(cd), (address, uint256));
            assertEq(tok, address(underlying));
            assertEq(amt, pulledAmount, "addCollateral uses composer balance");
        }

        {
            (, bytes memory cd) = facade.getLastCall(quoted.length + 1);
            assertEq(bytes4(cd), SEL_DECREASE_DEBT);
            uint256 amt = abi.decode(_sliceCalldata(cd), (uint256));
            assertEq(amt, type(uint256).max, "decreaseDebt arg = uint256.max");
        }

        {
            (, bytes memory cd) = facade.getLastCall(quoted.length + 2);
            assertEq(bytes4(cd), SEL_WITHDRAW_COLLATERAL);
            (address tok, uint256 amt, address to) = abi.decode(_sliceCalldata(cd), (address, uint256, address));
            assertEq(tok, address(underlying));
            assertEq(amt, type(uint256).max, "withdraw residue sentinel");
            assertEq(to, user, "residue goes to callerAddress");
        }
    }

    function test_gearboxV3_repay_all_no_quoted_tokens() public {
        _fundPoolLiquidity(100e6);
        _seedDebt(100e6);
        _prime(underlying, user, 105e6);

        address[] memory quoted = new address[](0);

        bytes memory data = abi.encodePacked(
            _transferInOp(underlying, 105e6),
            CalldataLib.encodeGearboxV3RepayAll(
                address(underlying), creditAccount, address(facade), creditManager, quoted
            )
        );

        vm.prank(user);
        composer.deltaCompose(data);

        // No quota strip → only addCollateral + decreaseDebt + withdrawCollateral = 3
        assertEq(facade.lastCallsLength(), 3);
        assertEq(facade.debt(), 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Generic multicall — openCreditAccount onBehalfOf pinning
    // ─────────────────────────────────────────────────────────────────────────

    function test_gearboxV3_open_credit_account_pins_onBehalfOf_to_caller() public {
        _prime(collToken, user, 10e8);
        _fundPoolLiquidity(1_000e6);

        // Build a minimal inner multicall: addCollateral + increaseDebt + setFullCheck
        bytes memory inner0 = abi.encodeWithSelector(SEL_ADD_COLLATERAL, address(collToken), uint256(2e8));
        bytes memory inner1 = abi.encodeWithSelector(SEL_INCREASE_DEBT, uint256(500e6));
        bytes memory inner2 = abi.encodeWithSelector(SEL_SET_FULL_CHECK, new uint256[](0), uint16(11000));

        bytes memory packed = abi.encodePacked(
            CalldataLib.encodeGearboxV3FacadeCall(inner0),
            CalldataLib.encodeGearboxV3FacadeCall(inner1),
            CalldataLib.encodeGearboxV3FacadeCall(inner2)
        );

        bytes memory data = abi.encodePacked(
            _transferInOp(collToken, 2e8),
            CalldataLib.encodeApprove(address(collToken), creditManager),
            CalldataLib.encodeGearboxV3OpenCreditAccount(address(facade), 42, 3, packed)
        );

        vm.prank(user);
        composer.deltaCompose(data);

        assertTrue(facade.lastKindOpen(), "kind=openCreditAccount");
        assertEq(facade.lastOnBehalfOf(), user, "onBehalfOf pinned to deltaCompose caller");
        assertEq(facade.lastRefCode(), 42, "referralCode forwarded");
        assertEq(facade.lastCallsLength(), 3);
        assertEq(facade.debt(), 500e6);
    }

    function test_gearboxV3_generic_bot_multicall_relays_calldata_verbatim() public {
        // Construct three facade-inner calls — including one that doesn't have a dedicated
        // primitive (updateQuota).
        bytes memory inner0 = abi.encodeWithSelector(SEL_UPDATE_QUOTA, address(collToken), int96(100_000), uint96(0));
        bytes memory inner1 = abi.encodeWithSelector(SEL_SET_FULL_CHECK, new uint256[](0), uint16(10500));

        bytes memory packed = abi.encodePacked(
            CalldataLib.encodeGearboxV3FacadeCall(inner0), CalldataLib.encodeGearboxV3FacadeCall(inner1)
        );

        bytes memory data =
            CalldataLib.encodeGearboxV3BotMulticall(address(facade), creditAccount, creditManager, 2, packed);

        vm.prank(user);
        composer.deltaCompose(data);

        assertFalse(facade.lastKindOpen());
        assertEq(facade.lastCa(), creditAccount);
        assertEq(facade.lastCallsLength(), 2);

        (, bytes memory cd0) = facade.getLastCall(0);
        assertEq(bytes4(cd0), SEL_UPDATE_QUOTA);
        (address tok, int96 qc, uint96 minQ) = abi.decode(_sliceCalldata(cd0), (address, int96, uint96));
        assertEq(tok, address(collToken));
        assertEq(qc, int96(100_000), "updateQuota arg relayed unchanged");
        assertEq(minQ, uint96(0));
    }

    function test_gearboxV3_generic_multicall_rejects_unknown_kind() public {
        // Build a LENDING/GEARBOX_MULTICALL op with kind = 2 (close — unreachable by design).
        bytes memory packed = CalldataLib.encodeGearboxV3FacadeCall(abi.encodeWithSelector(SEL_SET_FULL_CHECK, new uint256[](0), uint16(10000)));
        bytes memory data = abi.encodePacked(
            uint8(0x30), // ComposerCommands.LENDING
            uint8(13), // LenderOps.GEARBOX_MULTICALL
            uint16(9999), // lender in UP_TO_GEARBOX_V3 range
            uint8(2), // kind = 2 (invalid)
            address(facade),
            address(0), // creditAccount slot
            address(0), // creditManager slot
            bytes32(0), // referralCode
            uint16(1),
            packed
        );

        vm.prank(user);
        vm.expectRevert();
        composer.deltaCompose(data);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Strip the 4-byte selector from a bytes blob.
    function _sliceCalldata(bytes memory cd) internal pure returns (bytes memory out) {
        uint256 len = cd.length - 4;
        out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = cd[4 + i];
        }
    }

    function _seedCaEscrow(address tok, uint256 amt) internal {
        facade.setCaBalance(tok, amt);
    }

    function _seedDebt(uint256 amt) internal {
        // Models an outstanding debt of `amt` with no pre-existing underlying sitting on the CA.
        // The facade's token balance (from `_fundPoolLiquidity`) represents the pool side; it's
        // what `decreaseDebt` will receive via `POOL_SINK` transfer — not caBalances.
        facade.setDebt(amt);
    }
}
