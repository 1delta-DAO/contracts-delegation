// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Gearbox V3 Credit Accounts.
 *
 * @dev Every Gearbox V3 borrower-side op goes through `CreditFacadeV3.botMulticall(ca, MultiCall[])`
 *      (for existing CAs; the composer is never the CA owner so direct `multicall` is unreachable)
 *      or through `openCreditAccount(onBehalfOf, MultiCall[], refCode)` (for new CAs).
 *      The composer must be pre-registered as a bot on each CA with the minimum permission mask
 *      for the intended flow — see `GEARBOX.md §2` for the UX.
 *
 * @dev Approval target for any `addCollateral` is the **CreditManager**, not the facade. Encoders
 *      emit one `APPROVE(token, creditManager)` op in front of any supply/repay primitive; the
 *      composer's approval bookkeeping skips repeats.
 *
 * @dev No adapter support by design. Every `MultiCall.target` constructed here is the facade
 *      itself; the generic `gearboxMulticall` op rejects any sub-call whose relayed calldata
 *      doesn't match a facade-recognized selector. External protocol calls are out of scope;
 *      use the composer's native primitives + flash loans for cross-lender logic.
 *
 * @dev Aave-parallel primitives map onto Gearbox ops as follows. Each primitive emits a
 *      single `botMulticall(ca, …)` with a bounded sub-call list plus an optional
 *      `setFullCheckParams(minHF)` tail. Chaining per-primitive composer ops pays N collateral
 *      checks — for multi-action flows prefer `GEARBOX_MULTICALL`:
 *
 *        DEPOSIT  → [addCollateral, (setFullCheckParams)]
 *        BORROW   → [increaseDebt, withdrawCollateral(underlying, amt, to), setFullCheckParams]
 *        REPAY    → [addCollateral(underlying, amt), decreaseDebt(amt)]                  // partial
 *                 → [updateQuota(tok_i, int96.min, 0) × N,
 *                    addCollateral(underlying, balanceOf(this)),
 *                    decreaseDebt(uint256.max),                // CM caps to maxRepayment
 *                    withdrawCollateral(underlying, uint256.max, caller)]                 // full
 *        WITHDRAW → [withdrawCollateral, setFullCheckParams]
 */
abstract contract GearboxV3Lending is ERC20Selectors, Masks, DeltaErrors {
    // ─────────────────────────────────────────────────────────────────────────────
    // Facade multicall inner-op selectors (IDs from ICreditFacadeV3Multicall)
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev addCollateral(address,uint256)
    bytes32 internal constant GEARBOX_ADD_COLLATERAL = 0x6d75b9ee00000000000000000000000000000000000000000000000000000000;

    /// @dev increaseDebt(uint256)
    bytes32 internal constant GEARBOX_INCREASE_DEBT = 0x2b7c7b1100000000000000000000000000000000000000000000000000000000;

    /// @dev decreaseDebt(uint256)
    bytes32 internal constant GEARBOX_DECREASE_DEBT = 0x2a7ba1f700000000000000000000000000000000000000000000000000000000;

    /// @dev withdrawCollateral(address,uint256,address)
    bytes32 internal constant GEARBOX_WITHDRAW_COLLATERAL = 0x1f1088a000000000000000000000000000000000000000000000000000000000;

    /// @dev setFullCheckParams(uint256[],uint16)
    bytes32 internal constant GEARBOX_SET_FULL_CHECK_PARAMS = 0x0768bbfe00000000000000000000000000000000000000000000000000000000;

    /// @dev updateQuota(address,int96,uint96)
    bytes32 internal constant GEARBOX_UPDATE_QUOTA = 0x712c10ad00000000000000000000000000000000000000000000000000000000;

    // ─────────────────────────────────────────────────────────────────────────────
    // Facade entrypoint selectors
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev botMulticall(address,(address,bytes)[])
    bytes32 internal constant GEARBOX_BOT_MULTICALL = 0x7e2ca9db00000000000000000000000000000000000000000000000000000000;

    /// @dev openCreditAccount(address,(address,bytes)[],uint256)
    bytes32 internal constant GEARBOX_OPEN_CREDIT_ACCOUNT = 0x92beab1d00000000000000000000000000000000000000000000000000000000;

    /// @dev getBorrowerOrRevert(address) — ICreditManagerV3 auth helper.
    bytes32 internal constant GEARBOX_GET_BORROWER_OR_REVERT = 0xc53afb1e00000000000000000000000000000000000000000000000000000000;

    /// @dev creditManager() — shared by ICreditAccountV3 and ICreditFacadeV3 (same selector).
    ///      Called on the credit account to derive the CM; the CM is then used to derive the
    ///      facade and to authenticate the caller. Nothing in the auth chain comes from calldata.
    bytes32 internal constant GEARBOX_CREDIT_MANAGER_GETTER = 0xc12c21c000000000000000000000000000000000000000000000000000000000;

    /// @dev creditFacade() — ICreditManagerV3 immutable getter. Used to derive the facade the
    ///      composer will dispatch through, chained from the CM that was itself derived from the
    ///      credit account. This completes the CA → CM → facade derivation chain so no address
    ///      in the auth path ever comes from unverified calldata.
    bytes32 internal constant GEARBOX_CREDIT_FACADE_GETTER = 0x2f7a188100000000000000000000000000000000000000000000000000000000;

    /// @dev calcDebtAndCollateral(address,uint8) — returns a `CollateralDebtData` struct. The
    ///      composer uses task = 1 (`DEBT_ONLY`, the cheapest option that fills the debt + interest
    ///      + fee fields). See `_gearboxReadMaxRepay`.
    bytes32 internal constant GEARBOX_CALC_DEBT_AND_COLLATERAL =
        0x0d334ca600000000000000000000000000000000000000000000000000000000;

    /**
     * @dev Authenticates that `callerAddress` (the authenticated deltaCompose caller) is the
     *      borrower of `creditAccount`. Returns both the derived CreditManager and the derived
     *      CreditFacade so callers can dispatch without additional staticcalls.
     *
     *      Derivation chain (mirrors AccountMigratorBot — nothing comes from calldata):
     *        1. creditManager := creditAccount.creditManager()   — immutable in every Gearbox CA
     *        2. creditFacade  := creditManager.creditFacade()    — immutable in CreditManagerV3
     *        3. borrower      := creditManager.getBorrowerOrRevert(creditAccount)
     *           require borrower == callerAddress
     *
     *      This eliminates every calldata-injection vector in the auth path:
     *        - Attacker cannot supply a fake facade to spoof the CM (CM comes from the CA).
     *        - Attacker cannot supply a fake CM to spoof the facade (facade comes from the CM
     *          that was itself derived from the CA).
     *        - Attacker cannot supply victim's real CA (real CM reports victim as borrower →
     *          auth fails for non-victim caller).
     *        - Attacker can supply their own real CA with a malicious inner CM/facade chain,
     *          but then dispatch is scoped to their own CA; Gearbox's per-CA bot-permission
     *          registry prevents any cross-CA effect.
     *
     *      `openCreditAccount` (kind=1 of `GEARBOX_MULTICALL`) does NOT need this auth — that
     *      entrypoint has no caller check on Gearbox's side (the CA is brand new), and the
     *      composer pins `onBehalfOf = callerAddress` so there is no way to spoof the borrower.
     */
    function _gearboxAuthCaller(
        address creditAccount,
        address callerAddress
    )
        private
        view
        returns (address creditManager, address creditFacade)
    {
        assembly {
            // 1. creditManager := creditAccount.creditManager()
            mstore(0x0, GEARBOX_CREDIT_MANAGER_GETTER)
            if iszero(staticcall(gas(), creditAccount, 0x0, 0x4, 0x0, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            creditManager := mload(0x0)

            // 2. creditFacade := creditManager.creditFacade()
            mstore(0x0, GEARBOX_CREDIT_FACADE_GETTER)
            if iszero(staticcall(gas(), creditManager, 0x0, 0x4, 0x0, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            creditFacade := mload(0x0)

            // 3. borrower := creditManager.getBorrowerOrRevert(creditAccount); require == callerAddress
            mstore(0x0, GEARBOX_GET_BORROWER_OR_REVERT)
            mstore(0x4, creditAccount)
            if iszero(staticcall(gas(), creditManager, 0x0, 0x24, 0x0, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            if xor(mload(0x0), callerAddress) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
        }
    }

    /**
     * @dev Returns the exact amount of underlying the CM would consume if `decreaseDebt(max)` were
     *      called right now: `debt + accruedInterest + accruedFees` (Gearbox's `calcTotalDebt`).
     *      This equals `maxRepayment` for non-USDT pools (where CreditManagerV3's `_amountWithFee`
     *      is the identity). USDT-fee pools would slightly overshoot this read; not a concern on
     *      any current V3 pool (no fee-on-transfer USDT in production).
     *
     *      Same-tx race: the read and the subsequent `botMulticall` run in the same transaction
     *      without intervening state mutations to the CA's debt fields. `updateQuota` settles
     *      quota fees but does not change the debt+interest+fees sum. So the read at dispatch
     *      equals the value `decreaseDebt(max)` clamps to at consumption.
     *
     *      Struct-with-dynamic-fields returndata layout (CollateralDebtData has `address[]`):
     *        ptr + 0x00 : outer tuple offset (= 0x20, ignored)
     *        ptr + 0x20 : debt
     *        ptr + 0x40 : cumulativeIndexNow
     *        ptr + 0x60 : cumulativeIndexLastUpdate
     *        ptr + 0x80 : cumulativeQuotaInterest (padded)
     *        ptr + 0xa0 : accruedInterest
     *        ptr + 0xc0 : accruedFees
     */
    function _gearboxReadMaxRepay(address creditManager, address creditAccount) private view returns (uint256 maxRepay) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, GEARBOX_CALC_DEBT_AND_COLLATERAL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 1) // CollateralCalcTask.DEBT_ONLY
            // We need returndata bytes 0..0xe0 to reach `accruedFees`. Buffer 0x100.
            if iszero(staticcall(gas(), creditManager, ptr, 0x44, ptr, 0x100)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            let debt := mload(add(ptr, 0x20))
            let accruedInterest := mload(add(ptr, 0xa0))
            let accruedFees := mload(add(ptr, 0xc0))
            maxRepay := add(add(debt, accruedInterest), accruedFees)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Constants used when composing inner MultiCall arrays
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev int96.min — the "fully disable quota" sentinel documented in
    ///      `ICreditFacadeV3Multicall.updateQuota`.
    int96 internal constant GEARBOX_INT96_MIN = type(int96).min;

    /// @dev `kind` byte values for GEARBOX_MULTICALL:
    ///        0 → botMulticall(ca, calls)
    ///        1 → openCreditAccount(onBehalfOf=callerAddress, calls, referralCode)
    uint256 internal constant GEARBOX_KIND_BOT_MULTICALL = 0;
    uint256 internal constant GEARBOX_KIND_OPEN = 1;

    /// @dev Gearbox's `BotListV3.setBotPermissions` enforces `IBot(bot).requiredPermissions() == permissions`
    ///      — users must grant EXACTLY this mask, not a subset. The composer therefore exposes a fixed
    ///      "full lending" mask covering every op it emits:
    ///        bit 0  ADD_COLLATERAL_PERMISSION
    ///        bit 1  INCREASE_DEBT_PERMISSION
    ///        bit 2  DECREASE_DEBT_PERMISSION
    ///        bit 5  WITHDRAW_COLLATERAL_PERMISSION
    ///        bit 6  UPDATE_QUOTA_PERMISSION
    ///      `SET_BOT_PERMISSIONS_PERMISSION` (bit 8) is never requested — bots cannot escalate themselves.
    ///      `EXTERNAL_CALLS_PERMISSION` (bit 16) is omitted too — the composer never calls adapters
    ///      inside a Gearbox multicall (no-adapter policy, see GEARBOX.md §1).
    uint192 internal constant GEARBOX_COMPOSER_REQUIRED_PERMISSIONS =
        uint192((1 << 0) | (1 << 1) | (1 << 2) | (1 << 5) | (1 << 6));

    /// @notice Implements `IBot.requiredPermissions()` from Gearbox V3's BotListV3 — the mask that
    ///         users must grant (exactly) via `facade.multicall([setBotPermissions(composer, mask)])`.
    function requiredPermissions() external pure returns (uint192) {
        return GEARBOX_COMPOSER_REQUIRED_PERMISSIONS;
    }

    /**
     * @notice Supplies collateral to a Gearbox V3 Credit Account.
     * @dev Requires the composer to hold `ADD_COLLATERAL_PERMISSION` on `ca` (granted by the CA
     *      owner via a direct `facade.multicall([setBotPermissions(composer, mask)])` — not
     *      through the composer, since `setBotPermissions` is borrower-only).
     *
     *      Authentication: `callerAddress` must equal `ca.borrower`. Without this check any
     *      caller could invoke `deltaCompose` with someone else's bot-enabled CA and drain it.
     *
     *      Amount handling:
     *        - `amount == 0`: composer pulls its own `balanceOf(this)` of `underlying`.
     *        - otherwise:     uses the literal amount. The encoder is responsible for the
     *                         preceding `TRANSFER_FROM(user, composer, amount)` hop.
     *
     *      Token must be pre-approved to the CreditManager (encoder emits `APPROVE(token, cm)`).
     *
     * @dev HF buffer is not a primitive-level concern — Gearbox's facade enforces HF ≥ 1.0 by
     *      default. Callers who want a user-signed buffer should use `GEARBOX_MULTICALL` with an
     *      explicit `setFullCheckParams` sub-call.
     *
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                      |
     * |--------|----------------|--------------------------------------------------|
     * | 0      | 20             | underlying                                       |
     * | 20     | 16             | amount (0 = use composer balance)                |
     * | 36     | 20             | creditAccount                                    |
     */
    function _depositToGearboxV3(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        address creditAccount;
        address creditFacade;
        assembly {
            creditAccount := shr(96, calldataload(add(currentOffset, 36)))
        }
        (, creditFacade) = _gearboxAuthCaller(creditAccount, callerAddress);

        assembly {
            let token := shr(96, calldataload(currentOffset))
            let amount := and(UINT112_MASK, shr(128, calldataload(add(currentOffset, 20))))
            currentOffset := add(currentOffset, 56)

            if iszero(amount) {
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                if iszero(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)
            }

            let ptr := mload(0x40)

            // botMulticall(ca, [addCollateral(token, amount)]) — single tuple, always no HF tuple.
            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), 1) // calls.length
            mstore(add(ptr, 0x64), 0x20) // head[0]

            // tuple 0 at ptr + 0x84
            mstore(add(ptr, 0x84), creditFacade)
            mstore(add(ptr, 0xa4), 0x40)
            mstore(add(ptr, 0xc4), 0x44) // callData length = 68
            mstore(add(ptr, 0xe4), GEARBOX_ADD_COLLATERAL)
            mstore(add(ptr, 0xe8), token)
            mstore(add(ptr, 0x108), amount)
            mstore(add(ptr, 0x128), 0) // pad trailing 28 bytes

            if iszero(call(gas(), creditFacade, 0x0, ptr, 0x144, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /**
     * @notice Borrows underlying from a Gearbox V3 Credit Account and sends it to a receiver.
     * @dev Requires the composer to hold `INCREASE_DEBT_PERMISSION | WITHDRAW_COLLATERAL_PERMISSION`
     *      on `ca`. The `underlying` parameter must match the pool's underlying — mismatch reverts
     *      at the facade during `withdrawCollateral` since the CA has no non-underlying balance to
     *      draw from after `increaseDebt`.
     *
     *      HF buffer is not a primitive-level concern — Gearbox's facade enforces HF ≥ 1.0 by
     *      default. Callers who want a user-signed buffer should use `GEARBOX_MULTICALL` with an
     *      explicit `setFullCheckParams` sub-call.
     *
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                      |
     * |--------|----------------|--------------------------------------------------|
     * | 0      | 20             | underlying                                       |
     * | 20     | 16             | amount                                           |
     * | 36     | 20             | receiver                                         |
     * | 56     | 20             | creditAccount                                    |
     */
    function _borrowFromGearboxV3(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        address underlying;
        uint256 amount;
        address receiver;
        address creditAccount;
        assembly {
            underlying := shr(96, calldataload(currentOffset))
            amount := and(UINT112_MASK, shr(128, calldataload(add(currentOffset, 20))))
            receiver := shr(96, calldataload(add(currentOffset, 36)))
            creditAccount := shr(96, calldataload(add(currentOffset, 56)))
        }
        (, address creditFacade) = _gearboxAuthCaller(creditAccount, callerAddress);
        _gearboxBorrowRelay(underlying, amount, receiver, creditAccount, creditFacade);
        return currentOffset + 76;
    }

    /**
     * @dev Helper — builds and dispatches a `botMulticall(ca, [increaseDebt, withdrawCollateral])`.
     *      The facade's default HF ≥ 1.0 check always runs at the end — no `setFullCheckParams`.
     */
    function _gearboxBorrowRelay(
        address underlying,
        uint256 amount,
        address receiver,
        address creditAccount,
        address creditFacade
    )
        private
    {
        assembly {
            let ptr := mload(0x40)
            // Layout:
            //   tuple 0 increaseDebt:          size 0xa0
            //   tuple 1 withdrawCollateral:    size 0xe0
            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), 2)
            mstore(add(ptr, 0x64), 0x40) // head[0] = 2 * 0x20
            mstore(add(ptr, 0x84), 0xe0) // head[1] = 0x40 + 0xa0

            // tuple 0 — increaseDebt(amount) at ptr + 0xa4
            mstore(add(ptr, 0xa4), creditFacade)
            mstore(add(ptr, 0xc4), 0x40)
            mstore(add(ptr, 0xe4), 0x24) // callData len = 36
            mstore(add(ptr, 0x104), GEARBOX_INCREASE_DEBT)
            mstore(add(ptr, 0x108), amount)
            mstore(add(ptr, 0x128), 0)

            // tuple 1 — withdrawCollateral(underlying, amount, receiver) at ptr + 0x144
            mstore(add(ptr, 0x144), creditFacade)
            mstore(add(ptr, 0x164), 0x40)
            mstore(add(ptr, 0x184), 0x64) // callData len = 100
            mstore(add(ptr, 0x1a4), GEARBOX_WITHDRAW_COLLATERAL)
            mstore(add(ptr, 0x1a8), underlying)
            mstore(add(ptr, 0x1c8), amount)
            mstore(add(ptr, 0x1e8), receiver)
            mstore(add(ptr, 0x208), 0)

            if iszero(call(gas(), creditFacade, 0x0, ptr, 0x224, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
    }

    /**
     * @notice Repays debt on a Gearbox V3 Credit Account. Three shapes discriminated by `amount`:
     *
     *         **Zero-means-balance** (`amount == 0`, `numQuoted == 0`): substitutes
     *         `balanceOf(composer, underlying)` for the amount and emits a literal partial —
     *         aligns with the zero-sentinel convention used by the other lenders in this
     *         composer (Aave, Morpho, etc.).
     *
     *         **Explicit literal** (`amount ∈ (0, UINT112_MASK)`, `numQuoted == 0`): emits
     *         `botMulticall(ca, [addCollateral(underlying, amount), decreaseDebt(amount)])` with
     *         the supplied amount. Caller is responsible for avoiding the `(0, minDebt)`
     *         remainder window.
     *
     *         **Safe max** (`amount == UINT112_MASK`): the "repay as much as possible safely"
     *         flag. On-chain reads `maxRepay` via `calcDebtAndCollateral(DEBT_ONLY)`, computes
     *         `amt = min(balanceOf(composer), maxRepay)`, then **degrades gracefully**:
     *           - `amt == maxRepay` AND `numQuoted > 0`: full close-out — strip the N quotas,
     *             deposit `maxRepay`, `decreaseDebt(uint256.max)`. Exact deposit; no trailing
     *             `withdrawCollateral(max)` sweep (fixes the drained-CA revert that afflicted
     *             the old `_repayGearboxV3Full`). Surplus (if `bal > maxRepay`) stays on the
     *             composer for explicit sweep — integrates cleanly with flash-close patterns.
     *           - otherwise: partial — `[addCollateral(amt), decreaseDebt(amt)]`. No quota
     *             strip. If the caller supplied `quotedTokens` but composer balance was short,
     *             the list is ignored (intentional: the caller is short of funds and we prefer
     *             executing a partial over reverting — "repay 99.9k of a 100k debt when 100 wei
     *             short" instead of failing outright).
     *
     *         The safe-max path may still revert if the resulting remainder lands in Gearbox's
     *         `(0, minDebt)` window — same policy as the Lista lender path; UI is expected to
     *         warn based on `minDebt`.
     *
     * @dev Race-free in-transaction: the `calcDebtAndCollateral` read and subsequent
     *      `botMulticall` run in the same tx; Gearbox accrues no additional interest between
     *      them (no state-root updates mid-tx), so the read matches what `decreaseDebt`
     *      consumes. See `_gearboxReadMaxRepay` NatSpec.
     *
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                                |
     * |--------|----------------|------------------------------------------------------------|
     * | 0      | 20             | underlying                                                 |
     * | 20     | 16             | amount (0 = use composer balance, UINT112_MASK = safe-max, else literal) |
     * | 36     | 20             | creditAccount                                              |
     * | 56     | 1              | numQuotedTokens (must be 0 for partial shapes)             |
     * | 57     | N × 20         | quotedTokens[] (only when safe-close with N > 0)           |
     */
    function _repayToGearboxV3(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        // Read the header; dispatch between the three shapes in Solidity so each variant's
        // inner multicall layout can be hand-packed without conditional bookkeeping inside one
        // assembly block.
        address underlying;
        uint256 amount;
        address creditAccount;
        uint256 numQuoted;
        assembly {
            underlying := shr(96, calldataload(currentOffset))
            amount := shr(128, calldataload(add(currentOffset, 20)))
            creditAccount := shr(96, calldataload(add(currentOffset, 36)))
            numQuoted := and(UINT8_MASK, shr(248, calldataload(add(currentOffset, 56))))
        }
        (address creditManager, address creditFacade) = _gearboxAuthCaller(creditAccount, callerAddress);

        // Safe clamp: both `0` and `UINT112_MASK` route here. Always does what's possible; never
        // reverts on arithmetic ("100k repay with 100 wei short" still executes as a 99.9k
        // partial). The close-out path only engages when bal is sufficient AND the caller
        // supplied a quotedTokens list.
        if (amount == UINT112_MASK) {
            uint256 maxRepay = _gearboxReadMaxRepay(creditManager, creditAccount);
            uint256 bal = _balanceOfSelf(underlying);
            uint256 amt = bal < maxRepay ? bal : maxRepay;
            if (amt == 0) _invalidOperation();

            if (amt == maxRepay && numQuoted > 0) {
                // Close-out: exact deposit, quota strip, decreaseDebt(max). No trailing sweep.
                _repayGearboxV3SafeClose(currentOffset + 57, underlying, creditAccount, creditFacade, maxRepay, numQuoted);
            } else {
                // Partial: either bal was short, or caller didn't supply quoted tokens. The
                // quoted list (if any) is deliberately ignored — the caller signaled close
                // intent but we can't close, so we execute what we can instead of reverting.
                _repayGearboxV3Partial(underlying, amt, creditAccount, creditFacade);
            }
            return currentOffset + 57 + numQuoted * 20;
        }

        if (amount == 0) {
            amount = _balanceOfSelf(underlying);
        }

        // Explicit-literal partial: caller-controlled amount in (0, UINT112_MASK).
        if (numQuoted != 0) _invalidOperation();
        _repayGearboxV3Partial(underlying, uint256(amount), creditAccount, creditFacade);
        return currentOffset + 57;
    }

    /// @dev ERC20 `balanceOf(address(this))` — helper shared by the REPAY shapes.
    function _balanceOfSelf(address token) private view returns (uint256 bal) {
        assembly {
            mstore(0, ERC20_BALANCE_OF)
            mstore(0x04, address())
            if iszero(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            bal := mload(0x0)
        }
    }

    /**
     * @dev Partial repay: `botMulticall(ca, [addCollateral(underlying, amount), decreaseDebt(amount)])`.
     *      `amount == 0` is rejected — zero-means-balance semantics would risk stranding residue
     *      on the CA if the composer balance exceeds `maxRepayment`. For full repay use the
     *      UINT112_MASK path which explicitly sweeps residue.
     */
    function _repayGearboxV3Partial(address underlying, uint256 amount, address creditAccount, address creditFacade) private {
        if (amount == 0) {
            _invalidOperation();
        }
        assembly {
            let ptr := mload(0x40)
            // 2 inner calls: addCollateral (0xa4 payload padded → tuple 0xc0),
            //                decreaseDebt (0x24 payload padded → tuple 0xa0)
            let numCalls := 2

            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), numCalls)
            mstore(add(ptr, 0x64), mul(numCalls, 0x20)) // head[0] = 0x40
            mstore(add(ptr, 0x84), add(mul(numCalls, 0x20), 0xc0)) // head[1] = 0x40 + 0xc0 = 0x100

            // tuple 0: addCollateral(underlying, amount) — at ptr + 0x64 + 0x40 = ptr + 0xa4
            let t0 := add(ptr, 0xa4)
            mstore(t0, creditFacade)
            mstore(add(t0, 0x20), 0x40)
            mstore(add(t0, 0x40), 0x44)
            mstore(add(t0, 0x60), GEARBOX_ADD_COLLATERAL)
            mstore(add(t0, 0x64), underlying)
            mstore(add(t0, 0x84), amount)
            mstore(add(t0, 0xa4), 0)

            // tuple 1: decreaseDebt(amount) — at t0 + 0xc0
            let t1 := add(t0, 0xc0)
            mstore(t1, creditFacade)
            mstore(add(t1, 0x20), 0x40)
            mstore(add(t1, 0x40), 0x24)
            mstore(add(t1, 0x60), GEARBOX_DECREASE_DEBT)
            mstore(add(t1, 0x64), amount)
            mstore(add(t1, 0x84), 0)

            let callSize := sub(add(t1, 0xa0), ptr)
            if iszero(call(gas(), creditFacade, 0x0, ptr, callSize, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
    }

    /**
     * @dev Pinned-close emitter. Emits `botMulticall(ca, [updateQuota × N, addCollateral(maxRepay),
     *      decreaseDebt(max)])`. Reuses the quota/addCollateral/decreaseDebt tuple writers; the
     *      intentional absence of a `withdrawCollateral(max)` tail is the fix for the old
     *      full-repay path's `AmountCantBeZeroException` on drained CAs — the deposit is exact,
     *      so nothing remains on the CA to sweep.
     *
     *      Surplus handling shifts to the caller: if `balanceOf(composer) > maxRepay` the
     *      surplus stays on the composer rather than being round-tripped through Gearbox. Flash
     *      close-out patterns naturally consume it for flash repayment; delever patterns add an
     *      explicit `TRANSFER` sweep downstream.
     */
    function _repayGearboxV3SafeClose(
        uint256 quotedTokensOffset,
        address underlying,
        address creditAccount,
        address creditFacade,
        uint256 maxRepay,
        uint256 numQuoted
    )
        private
    {
        uint256 ptr;
        assembly {
            ptr := mload(0x40)
            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), add(numQuoted, 2))
        }

        // Total calls = N + 2 (quotas + addCollateral + decreaseDebt). No sweep.
        uint256 cursor = _gearboxWriteQuotaTuples(ptr, quotedTokensOffset, numQuoted, numQuoted + 2, creditFacade);
        cursor = _gearboxWriteAddCollateralTuple(ptr, cursor, creditFacade, underlying, maxRepay, numQuoted);
        cursor = _gearboxWriteDecreaseDebtMaxTuple(ptr, cursor, creditFacade, numQuoted + 1);

        assembly {
            if iszero(call(gas(), creditFacade, 0x0, ptr, sub(cursor, ptr), 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
    }

    /// @dev Helper — writes N `updateQuota(tok_i, int96.min, 0)` tuples + their heads. Returns
    ///      the memory cursor just past the last tuple.
    ///
    ///      `totalCalls` is the total number of sub-calls in the outer multicall so this helper
    ///      can place the body cursor after the full heads-array of size `totalCalls * 0x20`.
    ///      Full-repay passes `numQuoted + 3` (N quotas + addCollateral + decreaseDebt +
    ///      withdrawCollateral sweep); safe-close passes `numQuoted + 2` (no sweep).
    function _gearboxWriteQuotaTuples(
        uint256 ptr,
        uint256 quotedTokensOffset,
        uint256 numQuoted,
        uint256 totalCalls,
        address creditFacade
    )
        private
        pure
        returns (uint256)
    {
        uint256 cursor;
        assembly {
            let headsBase := add(ptr, 0x64)
            cursor := add(headsBase, mul(totalCalls, 0x20))
            for { let i := 0 } lt(i, numQuoted) { i := add(i, 1) } {
                mstore(add(headsBase, mul(i, 0x20)), sub(cursor, headsBase))
                mstore(cursor, creditFacade)
                mstore(add(cursor, 0x20), 0x40)
                mstore(add(cursor, 0x40), 0x64)
                mstore(add(cursor, 0x60), GEARBOX_UPDATE_QUOTA)
                mstore(add(cursor, 0x64), shr(96, calldataload(add(quotedTokensOffset, mul(i, 20)))))
                // int96.min sign-extended to 256 bits
                mstore(add(cursor, 0x84), 0xffffffffffffffffffffffffffffffffffffffff800000000000000000000000)
                mstore(add(cursor, 0xa4), 0)
                mstore(add(cursor, 0xc4), 0)
                cursor := add(cursor, 0xe0)
            }
        }
        return cursor;
    }

    function _gearboxWriteAddCollateralTuple(
        uint256 ptr,
        uint256 cursor,
        address creditFacade,
        address underlying,
        uint256 amount,
        uint256 headIndex
    )
        private
        pure
        returns (uint256)
    {
        assembly {
            mstore(add(add(ptr, 0x64), mul(headIndex, 0x20)), sub(cursor, add(ptr, 0x64)))
            mstore(cursor, creditFacade)
            mstore(add(cursor, 0x20), 0x40)
            mstore(add(cursor, 0x40), 0x44)
            mstore(add(cursor, 0x60), GEARBOX_ADD_COLLATERAL)
            mstore(add(cursor, 0x64), underlying)
            mstore(add(cursor, 0x84), amount)
            mstore(add(cursor, 0xa4), 0)
            cursor := add(cursor, 0xc0)
        }
        return cursor;
    }

    function _gearboxWriteDecreaseDebtMaxTuple(
        uint256 ptr,
        uint256 cursor,
        address creditFacade,
        uint256 headIndex
    )
        private
        pure
        returns (uint256)
    {
        assembly {
            mstore(add(add(ptr, 0x64), mul(headIndex, 0x20)), sub(cursor, add(ptr, 0x64)))
            mstore(cursor, creditFacade)
            mstore(add(cursor, 0x20), 0x40)
            mstore(add(cursor, 0x40), 0x24)
            mstore(add(cursor, 0x60), GEARBOX_DECREASE_DEBT)
            mstore(add(cursor, 0x64), MAX_UINT256)
            mstore(add(cursor, 0x84), 0)
            cursor := add(cursor, 0xa0)
        }
        return cursor;
    }

    /**
     * @notice Withdraws collateral from a Gearbox V3 Credit Account.
     * @dev Requires the composer to hold `WITHDRAW_COLLATERAL_PERMISSION` on `ca`.
     *      Amount handling:
     *        - `amount == UINT112_MASK`: translated to `type(uint256).max` for Gearbox's own
     *          "sweep full balance" sentinel on `withdrawCollateral`.
     *        - otherwise: literal amount.
     *
     * @dev HF buffer is not a primitive-level concern — Gearbox's facade enforces HF ≥ 1.0 by
     *      default. Callers who want a user-signed buffer should use `GEARBOX_MULTICALL` with an
     *      explicit `setFullCheckParams` sub-call.
     *
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                      |
     * |--------|----------------|--------------------------------------------------|
     * | 0      | 20             | token                                            |
     * | 20     | 16             | amount (UINT112_MASK = withdraw all)             |
     * | 36     | 20             | receiver                                         |
     * | 56     | 20             | creditAccount                                    |
     */
    function _withdrawFromGearboxV3(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        address creditAccount;
        address creditFacade;
        assembly {
            creditAccount := shr(96, calldataload(add(currentOffset, 56)))
        }
        (, creditFacade) = _gearboxAuthCaller(creditAccount, callerAddress);

        assembly {
            let token := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let receiver := shr(96, calldataload(add(currentOffset, 36)))
            currentOffset := add(currentOffset, 76)

            let amount := and(UINT112_MASK, amountData)
            if eq(amount, UINT112_MASK) { amount := MAX_UINT256 }

            let ptr := mload(0x40)

            // botMulticall(ca, [withdrawCollateral(token, amount, receiver)]) — single tuple.
            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), 1)
            mstore(add(ptr, 0x64), 0x20) // head[0]

            // tuple 0 at ptr + 0x84 — withdrawCollateral callData = 100 bytes, padded to 128
            mstore(add(ptr, 0x84), creditFacade)
            mstore(add(ptr, 0xa4), 0x40)
            mstore(add(ptr, 0xc4), 0x64) // callData len = 100
            mstore(add(ptr, 0xe4), GEARBOX_WITHDRAW_COLLATERAL)
            mstore(add(ptr, 0xe8), token)
            mstore(add(ptr, 0x108), amount)
            mstore(add(ptr, 0x128), receiver)
            mstore(add(ptr, 0x148), 0) // pad trailing 28 bytes

            if iszero(call(gas(), creditFacade, 0x0, ptr, 0x164, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /**
     * @notice Generic multicall relay — lets the encoder stream a compact `MultiCall[]` into
     *         either `botMulticall(ca, …)` or `openCreditAccount(callerAddress, …, refCode)`.
     *         Every sub-call's `target` is implicitly the encoded `creditFacade` — the no-adapter
     *         policy is enforced in code: the encoder supplies only inner calldata.
     *
     * @dev `kind=0` → `botMulticall(creditAccount, calls)`.
     *      `kind=1` → `openCreditAccount(callerAddress, calls, referralCode)` — `onBehalfOf` is
     *                 always `callerAddress` (the authenticated deltaCompose caller), never an
     *                 encoder-supplied address; otherwise a third-party-submitted composer call
     *                 could open a Credit Account owned by another user.
     *
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                               |
     * |--------|----------------|-----------------------------------------------------------|
     * | 0      | 1              | kind (0 = botMulticall, 1 = openCreditAccount)            |
     * | 1      | 20             | creditAccount (kind=0) OR creditFacade (kind=1)           |
     * | 21     | 20             | padding                                                   |
     * | 41     | 32             | referralCode (kind=1) or padding (kind=0)                 |
     * | 73     | 2              | numCalls (N, must be > 0)                                 |
     * | 75     | Σ              | N sub-calls: innerLen (2) | innerCalldata (innerLen)      |
     *
     * @dev Auth (kind=0 only): CM and facade are derived from `creditAccount` via the
     *      CA → CM → facade chain — nothing in the auth path comes from calldata.
     *      `kind=1` (`openCreditAccount`) needs no such check — the entrypoint has no caller
     *      constraint on Gearbox's side, and the composer pins `onBehalfOf = callerAddress`.
     *
     * @dev `kind=1` threat-model (read carefully — `addr1` is intentionally unconstrained):
     *
     *      The dispatch executes `addr1.openCreditAccount(callerAddress, calls, refCode)`
     *      with `callValue = 0` (see `_gearboxRelayOpen`). Allowlisting `addr1` would
     *      break dynamic integration as new CreditManagers/facades are deployed, so the
     *      design instead leans on four structural invariants:
     *
     *      (1) Zero value forwarded. The CALL passes `0` as msg.value, so no native asset
     *          can be siphoned to an attacker `addr1`.
     *
     *      (2) No standing approvals to `addr1`. Composer ERC20 approvals are issued by
     *          `_approve(token, target)` in the same batch and target the CreditManager
     *          (not the facade). An attacker `addr1` has no allowance to pull tokens.
     *
     *      (3) `onBehalfOf` is pinned to `callerAddress` in `_gearboxRelayOpen`'s mstore at
     *          ptr+0x04. The encoder cannot redirect the owner of the new CA to anyone
     *          else even for a legitimate facade.
     *
     *      (4) Re-entry is callerAddress-scoped. If `addr1` is attacker-controlled and
     *          calls back into `composer.deltaCompose(...)`, the inner batch runs with
     *          `callerAddress = attacker` (msg.sender of the inner call), so attacker
     *          ops can only act against attacker's own allowances/balances.
     *
     *      The only residual concern is the encoder embedding a hostile `addr1` alongside
     *      a `TRANSFER_FROM(user, composer, …)` op earlier in the same batch — then the
     *      composer holds user funds at dispatch time and a reentrant `_sweep` from the
     *      attacker could drain them. That requires the encoder to be hostile to the
     *      signer, which is encoder/UX trust, outside the contract's threat model.
     *
     *      Because `kind=1` carries no contract-level damage path under (1)–(4), no
     *      validation is performed on `addr1` here.
     */
    function _gearboxMulticall(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        uint256 kind;
        address addr1; // creditAccount for kind=0, creditFacade for kind=1
        uint256 numCalls;
        assembly {
            kind := shr(248, calldataload(currentOffset))
            addr1 := shr(96, calldataload(add(currentOffset, 1)))
            numCalls := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 73))))
        }
        if (kind > GEARBOX_KIND_OPEN || numCalls == 0) _invalidOperation();

        if (kind == GEARBOX_KIND_BOT_MULTICALL) {
            (, address creditFacade) = _gearboxAuthCaller(addr1, callerAddress);
            return _gearboxRelayBotMulticall(creditFacade, addr1, numCalls, currentOffset + 75);
        }
        // kind == GEARBOX_KIND_OPEN: addr1 is creditFacade (no CA to derive from yet)
        uint256 referralCode;
        assembly {
            referralCode := calldataload(add(currentOffset, 41))
        }
        return _gearboxRelayOpen(addr1, callerAddress, referralCode, numCalls, currentOffset + 75);
    }

    /**
     * @dev Build + dispatch `botMulticall(ca, calls)`. `subCallsOffset` points at the first
     *      sub-call header (innerLen(2) | innerCalldata(innerLen)) in the composer's input.
     *      Returns the offset immediately after the last sub-call.
     */
    function _gearboxRelayBotMulticall(
        address creditFacade,
        address creditAccount,
        uint256 numCalls,
        uint256 subCallsOffset
    )
        private
        returns (uint256 nextOffset)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), numCalls)
            let headsBase := add(ptr, 0x64)
            let bodyCursor := add(headsBase, mul(numCalls, 0x20))
            let readCursor := subCallsOffset

            for { let i := 0 } lt(i, numCalls) { i := add(i, 1) } {
                let innerLen := and(UINT16_MASK, shr(240, calldataload(readCursor)))
                readCursor := add(readCursor, 2)
                mstore(add(headsBase, mul(i, 0x20)), sub(bodyCursor, headsBase))
                mstore(bodyCursor, creditFacade)
                mstore(add(bodyCursor, 0x20), 0x40)
                mstore(add(bodyCursor, 0x40), innerLen)
                let dataStart := add(bodyCursor, 0x60)
                calldatacopy(dataStart, readCursor, innerLen)
                let paddedLen := and(add(innerLen, 31), not(31))
                if gt(paddedLen, innerLen) {
                    calldatacopy(add(dataStart, innerLen), calldatasize(), sub(paddedLen, innerLen))
                }
                bodyCursor := add(dataStart, paddedLen)
                readCursor := add(readCursor, innerLen)
            }

            if iszero(call(gas(), creditFacade, 0x0, ptr, sub(bodyCursor, ptr), 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            nextOffset := readCursor
        }
    }

    /**
     * @dev Build + dispatch `openCreditAccount(onBehalfOf=caller, calls, referralCode)`. Layout
     *      differs from `botMulticall` in the outer head (three static slots vs. one), so the
     *      heads-base offset shifts by 0x20.
     */
    function _gearboxRelayOpen(
        address creditFacade,
        address callerAddress,
        uint256 referralCode,
        uint256 numCalls,
        uint256 subCallsOffset
    )
        private
        returns (uint256 nextOffset)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, GEARBOX_OPEN_CREDIT_ACCOUNT)
            mstore(add(ptr, 0x04), callerAddress)
            mstore(add(ptr, 0x24), 0x60)
            mstore(add(ptr, 0x44), referralCode)
            mstore(add(ptr, 0x64), numCalls)
            let headsBase := add(ptr, 0x84)
            let bodyCursor := add(headsBase, mul(numCalls, 0x20))
            let readCursor := subCallsOffset

            for { let i := 0 } lt(i, numCalls) { i := add(i, 1) } {
                let innerLen := and(UINT16_MASK, shr(240, calldataload(readCursor)))
                readCursor := add(readCursor, 2)

                mstore(add(headsBase, mul(i, 0x20)), sub(bodyCursor, headsBase))
                mstore(bodyCursor, creditFacade)
                mstore(add(bodyCursor, 0x20), 0x40)
                mstore(add(bodyCursor, 0x40), innerLen)
                calldatacopy(add(bodyCursor, 0x60), readCursor, innerLen)
                let paddedLen := and(add(innerLen, 31), not(31))
                let padLen := sub(paddedLen, innerLen)
                if iszero(iszero(padLen)) {
                    calldatacopy(add(add(bodyCursor, 0x60), innerLen), calldatasize(), padLen)
                }
                bodyCursor := add(bodyCursor, add(0x60, paddedLen))
                readCursor := add(readCursor, innerLen)
            }

            if iszero(call(gas(), creditFacade, 0x0, ptr, sub(bodyCursor, ptr), 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            nextOffset := readCursor
        }
    }
}
