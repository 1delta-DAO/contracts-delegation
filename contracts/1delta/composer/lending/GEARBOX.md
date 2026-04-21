# Gearbox V3 — Composer integration

Companion to [GEARBOX_AGGREGATOR_INTEGRATION.md](GEARBOX_AGGREGATOR_INTEGRATION.md).
This doc describes how Gearbox V3 is wired into the 1delta composer so that
the existing Aave-parallel calldata surface (`DEPOSIT` / `BORROW` / `REPAY` /
`WITHDRAW`) behaves the same way it does for Aave, Compound, Fluid, and the
rest — and where Gearbox's own invariants force us to deviate.

---

## 1. Why Gearbox is different

Most composer lenders have direct per-op entrypoints
(`pool.supply(token, amt, user)`, `pool.borrow(…)`, etc.). Gearbox doesn't.

Every borrower-side action goes through the **CreditFacadeV3**:

| Entrypoint | Auth | Used by composer |
|---|---|---|
| `multicall(ca, calls)` | `msg.sender == CA owner` | Never — composer is not the owner |
| `botMulticall(ca, calls)` | Composer holds a bot role on `ca` | All primitives + generic multicall |
| `openCreditAccount(onBehalfOf, calls, refCode)` | Anyone; `onBehalfOf` becomes the new borrower | Mode C "open and deliver" |
| `closeCreditAccount(ca, calls)` | `msg.sender == CA owner` | Never — composer is not the owner |

Consequences for the composer model:

1. **The composer is always operating as a bot.** There is no code path in
   which the composer is the CA owner. `multicall` and `closeCreditAccount`
   are therefore unreachable from the composer and the generic multicall op
   rejects those entrypoints. To close a position, a user calls the facade
   directly, or opens a fresh CA via `openCreditAccount` and walks the old
   one down via a sequence of `botMulticall`s.
2. **One-time bot grant required.** Before any `botMulticall`-backed op can
   run for a given CA, the user must run a single direct tx against the
   facade:
   ```
   facade.multicall(ca, [setBotPermissions(composer, mask)])
   ```
   The composer cannot do this on the user's behalf — `setBotPermissions` is
   inside a `multicall`, which is borrower-only. See §4.
3. **Approvals go to the CreditManager, not the facade.** `addCollateral`'s
   `safeTransferFrom` is executed by the CM, with `msg.sender` of the facade
   call (the composer) as payer. Existing `encodeApprove(token, creditManager)`
   fits.
4. **Every state-changing multicall ends with a full collateral/HF check.**
   Chaining N composer primitives costs N collateral checks. For compound
   flows (supply + borrow, migrate + leverage, full exit), use
   `GEARBOX_MULTICALL` to put everything in one inner multicall and pay the
   check once.
5. **No adapters.** Gearbox's adapter allowlist is not used here. Every
   `MultiCall.target` built by the composer is the facade itself. The
   generic multicall op enforces `target == facade` for every sub-call —
   attempting to route through an adapter from the composer reverts. This
   is a deliberate design choice; adapters are not flexible enough for our
   pipeline, and we route all non-Gearbox logic (swaps, LPs, cross-lender
   hops) through the composer's existing primitives plus external flash
   loans.

---

## 2. Permission UX

### 2.1 Granting — one direct call to the facade, from the user

The user must personally sign one transaction (not through the composer):

```solidity
bytes[] memory calls = new bytes[](1);
calls[0] = abi.encodeCall(
    ICreditFacadeV3Multicall.setBotPermissions,
    (composer, mask)
);
ICreditFacadeV3(facade).multicall(ca, calls);
```

Permission masks — use the minimum for the flow in question:

```
SUPPLY_ONLY       = ADD_COLLATERAL_PERMISSION
WITHDRAW_ONLY     = WITHDRAW_COLLATERAL_PERMISSION
BORROW_BUNDLE     = INCREASE_DEBT_PERMISSION | WITHDRAW_COLLATERAL_PERMISSION
REPAY_BUNDLE      = ADD_COLLATERAL_PERMISSION | DECREASE_DEBT_PERMISSION | UPDATE_QUOTA_PERMISSION
FULL_LENDING      = ADD_COLLATERAL_PERMISSION
                  | WITHDRAW_COLLATERAL_PERMISSION
                  | INCREASE_DEBT_PERMISSION
                  | DECREASE_DEBT_PERMISSION
                  | UPDATE_QUOTA_PERMISSION
```

`SET_BOT_PERMISSIONS_PERMISSION` is always stripped by the facade
(`BOT_ALLOWED_PERMISSIONS`). A bot cannot escalate itself.

### 2.2 Revocation — symmetric, owner-only

Same shape as grant; the mask is zero:

```solidity
calls[0] = abi.encodeCall(
    ICreditFacadeV3Multicall.setBotPermissions,
    (composer, 0)
);
ICreditFacadeV3(facade).multicall(ca, calls);
```

### 2.3 Global bot ban recovery

Gearbox governance can globally ban the composer via
`BotListV3.setBotForbiddenStatus(composer, true)`. Every `botMulticall` then
reverts for every CA with that bot role. Recovery path for users:

1. The composer can still run `openCreditAccount(user, …)` — the
   `OPEN_CREDIT_ACCOUNT_PERMISSIONS` mask bypasses the bot list entirely for
   the opening multicall.
2. Users can still revoke the (now-inert) bot role via a direct
   `facade.multicall([setBotPermissions(composer, 0)])`.
3. For existing CAs, migration is: user opens a new CA directly against the
   facade, or swaps in a different bot aggregator.

Don't rely on `botMulticall` being reachable forever. For any one-shot
leverage, prefer Mode C.

---

## 3. Calldata surface

### 3.1 Aave-parallel primitives

All four dispatch on `lender < LenderIds.UP_TO_GEARBOX_V3` inside the
existing `LenderOps.DEPOSIT/BORROW/REPAY/WITHDRAW` handlers.
Calldata layouts (after the 3-byte op + lender header):

#### `DEPOSIT` (`_depositToGearboxV3`)

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 20 | underlying |
| 20 | 16 | amount (0 = use composer balance) |
| 36 | 20 | creditAccount |
| 56 | 20 | creditFacade |
| 76 | 2 | minHealthFactor (bps; 0 = skip `setFullCheckParams`) |

Emits `facade.botMulticall(ca, [addCollateral(underlying, amount), setFullCheckParams(minHF)])`.
Token must be pre-approved to the CreditManager (encoder emits one
`APPROVE` op in front).

#### `BORROW` (`_borrowFromGearboxV3`)

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 20 | underlying (must equal the pool's underlying) |
| 20 | 16 | amount |
| 36 | 20 | receiver |
| 56 | 20 | creditAccount |
| 76 | 20 | creditFacade |
| 96 | 2 | minHealthFactor (bps; **required > 10000**) |

Emits `botMulticall(ca, [increaseDebt(amount), withdrawCollateral(underlying, amount, receiver), setFullCheckParams(minHF)])`.

`minHealthFactor` is not optional on borrow — a borrow that lands at the
default facade floor of 10000 bps (HF = 1.0) is a liquidation waiting on
the next oracle tick. Encoders should pass `>= 10500` for user flows.

#### `REPAY` (`_repayToGearboxV3`)

Two shapes, discriminated by `amount`:

**Partial (`amount` ∈ (0, UINT112_MASK))**

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 20 | underlying |
| 20 | 16 | amount (must be > 0 — zero-means-balance is rejected) |
| 36 | 20 | creditAccount |
| 56 | 20 | creditFacade |
| 76 | 1 | numQuotedTokens (must be 0) |

Emits `botMulticall(ca, [addCollateral(underlying, amount), decreaseDebt(amount)])`.

Caveats:
- `amount == 0` is rejected (`InvalidOperation`). Zero-means-balance on
  this primitive would risk stranding residue on the CA if the composer
  balance exceeds `maxRepayment`.
- If the post-repay debt would land in `(0, minDebt)`, the facade reverts
  with `BorrowAmountOutOfLimitsException`. Encoders either repay less so
  debt stays above `minDebt`, or use the full-repay path with
  `UINT112_MASK`.

**Full (`amount == UINT112_MASK`)**

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 20 | underlying |
| 20 | 16 | amount (= UINT112_MASK sentinel) |
| 36 | 20 | creditAccount |
| 56 | 20 | creditFacade |
| 76 | 1 | numQuotedTokens (N) |
| 77 | N × 20 | quotedTokens[] |

Emits a single `botMulticall(ca, [
    updateQuota(tok_0, type(int96).min, 0),
    …,
    updateQuota(tok_{N-1}, type(int96).min, 0),
    addCollateral(underlying, balanceOf(composer)),
    decreaseDebt(type(uint256).max),   // CM caps to maxRepayment internally
    withdrawCollateral(underlying, type(uint256).max, callerAddress)
])`.

See §5 for the reasoning behind each step.

#### `WITHDRAW` (`_withdrawFromGearboxV3`)

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 20 | token |
| 20 | 16 | amount (UINT112_MASK = withdraw all) |
| 36 | 20 | receiver |
| 56 | 20 | creditAccount |
| 76 | 20 | creditFacade |
| 96 | 2 | minHealthFactor (bps) |

Emits `botMulticall(ca, [withdrawCollateral(token, amountOrMax, receiver), setFullCheckParams(minHF)])`.

`UINT112_MASK` is translated to `type(uint256).max` for the
`withdrawCollateral` argument (Gearbox's own "sweep full balance" sentinel).

### 3.2 Generic multicall (`GEARBOX_MULTICALL`)

Dispatched on `lendingOperation == LenderOps.GEARBOX_MULTICALL` and
`lender ∈ [UP_TO_FLUID_SMART, UP_TO_GEARBOX_V3)`. Calldata:

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 1 | kind (0 = `botMulticall`, 1 = `openCreditAccount`) |
| 1 | 20 | creditFacade |
| 21 | 20 | creditAccount (kind=0) or referralTarget-placeholder (kind=1, ignored) |
| 41 | 32 | referralCode (kind=1) or padding (kind=0) |
| 73 | 2 | numCalls (N) |
| 75 | Σ (20 + 2 + len) | N sub-calls, each `facade (20) | innerLen (2) | innerCalldata (innerLen)` |

`kind=2` (closeCreditAccount) is reserved but unreachable (composer is not
the CA owner); the dispatcher rejects it.

Every sub-call's `target` is implicitly the `creditFacade` — the encoder
does **not** supply the target, and the composer hard-codes it. This is
the no-adapters policy in code.

For `kind=1` (`openCreditAccount`), `onBehalfOf` is **always**
`callerAddress` (the authenticated `deltaCompose` caller). The encoder
cannot spoof a different `onBehalfOf`. This prevents an attacker from
opening unauthorized CAs owned by other users via a third-party submitted
composer call.

---

## 4. End-to-end flows

### 4.1 Deposit + borrow (one botMulticall, two composer ops)

If the user wants atomicity and only one HF check, use
`GEARBOX_MULTICALL` with two inner sub-calls plus a trailing
`setFullCheckParams`. Splitting into `DEPOSIT` + `BORROW` works
functionally but costs two collateral checks.

### 4.2 Migration into Gearbox from another lender

Same as any composer migration: flash-loan the debt-asset → repay source
lender → withdraw source collateral → `GEARBOX_MULTICALL` with
`kind=openCreditAccount` supplying the full multicall to build the new
position → flash-loan repayment sweeps in the tail.

### 4.3 External-flash-loan leverage (parallel to Aave/Fluid)

Used when the user wants to leverage into Gearbox with a position shape
Gearbox's own pool can't provide (e.g., the collateral side is supplied
by a non-Gearbox pool). Shape:

```
deltaCompose([
    TRANSFERS.TRANSFER_FROM(user → composer, seed)
    FLASH_LOAN(flashAsset, flashAmt, [
        // callback body:
        LENDING.GEARBOX_V3.DEPOSIT(flashAsset + seed → ca)
        LENDING.GEARBOX_V3.BORROW(underlying, flashAmt + flashFee → composer)
        // flash repay happens in the flash-loan epilogue
    ])
])
```

The borrow leg sizes exactly `flashAmt + flashFee` so nothing is left on
the composer; the flash-loan callback returns the exact owed amount back
to the flash provider. The tail sweeps any residual seed remainder back
to the user.

### 4.4 Open and deliver (Mode C — no bot grant needed)

```
deltaCompose([
    TRANSFERS.TRANSFER_FROM(user → composer, seed)
    TRANSFERS.APPROVE(underlying, creditManager)
    LENDING.GEARBOX_V3.GEARBOX_MULTICALL[kind=openCreditAccount, facade, 0, refCode, [
        facadeCall(addCollateral(underlying, seed))
        facadeCall(increaseDebt(leverage))
        facadeCall(setFullCheckParams(hints, minHF))
    ]]
])
```

The facade mints a fresh CA with `callerAddress` as borrower. No bot role
is granted during the open — the user remains sole controller.

---

## 5. Full repay without dust or sporadic reverts

This is the only primitive that deliberately diverges from "one shot, no
on-chain reads." The requirement — no dust, no reverts — forces an
on-chain debt read at execution time, plus a buffer, plus a residue
sweep. Each step pays for a specific failure mode:

### 5.1 Why the naive path breaks

A quote-time read ("get current debt, pull exactly that much, repay") has
three independent failure modes:

1. **Interest drift.** Between quote and execution, `cumulativeQuotaInterest`
   and base `accruedInterest` tick up every second. Pulling the quoted
   amount leaves 1–N wei short; `decreaseDebt(amount)` cannot fully clear,
   debt lands in `(0, minDebt)`, revert with `BorrowAmountOutOfLimitsException`.
2. **Active quotas.** Gearbox does not allow a CA to carry non-zero
   quotas with zero debt. `decreaseDebt` that would zero debt reverts
   with `DebtToZeroWithActiveQuotasException` unless every quoted
   collateral token's quota is also zero.
3. **Residual collateral.** Even with debt zeroed, the CA still holds the
   buffered underlying the user pulled. If the composer returns a tx with
   dust stranded on the CA, the position is "still open with zero debt" —
   bad UX, potential attack surface if someone else can `addCollateral` and
   re-leverage a CA with state left over.

### 5.2 Key invariant — Gearbox caps `decreaseDebt` internally

`CreditManagerV3.manageDebt` (the only consumer of `decreaseDebt`
arguments) does this, in order:

```
maxRepayment = _amountWithFee(totalDebt);       // totalDebt = debt + accruedInterest + accruedFees
if (amount >= maxRepayment) amount = maxRepayment;
_safeTransfer(creditAccount → pool, amount);    // CA must hold `amount`
// … debt zeroed when amount == maxRepayment
```

Passing `type(uint256).max` as the `decreaseDebt` argument is therefore
safe and **zeros the debt atomically** — the CM caps to `maxRepayment`,
transfers exactly that from the CA to the pool. **No off-chain read or
buffer arithmetic required to hit the exact debt.** The only requirement
is that the CA already holds `maxRepayment` of underlying at the moment
of the call.

### 5.3 The four-step recipe (all inside one `botMulticall`)

0. **Off-chain, encoder side.** The encoder enumerates the CA's
   currently-enabled quoted tokens — reads
   `CreditManagerV3.enabledTokensMask(ca) & CreditManagerV3.quotedTokensMask()`
   and walks the bits to get the token list, then passes it in the
   calldata. The composer does not iterate on-chain.

1. **Pull buffered amount from the user** (prepended `TRANSFER_FROM` op).
   Encoder chooses `pulledAmount = quotedDebt * (1 + bufferBps/10000)`,
   with `bufferBps` large enough to cover (a) interest accrual between
   off-chain quote and tx inclusion, (b) any fee the underlying token
   takes on transfer. Recommended default: 50 bps. Oversizing is safe —
   anything above `maxRepayment` is swept back to the user at step 4.

2. **Strip quotas.** For each token in the quoted-tokens list, one
   `updateQuota(token, type(int96).min, 0)` sub-call. `type(int96).min`
   is the documented "fully disable" sentinel. Accrued quota interest
   is settled into base debt at this step so `maxRepayment` in step 3
   already includes it.

3. **Deposit the buffered underlying and decrease debt**:
   - `addCollateral(underlying, pulledAmount)` — the composer reads
     `pulledAmount` from `balanceOf(this)` at execution time so the
     encoder doesn't need to know the exact figure.
   - `decreaseDebt(type(uint256).max)` — CM caps internally to the
     exact `maxRepayment` (see §5.2). Zeros debt atomically.

4. **Sweep residue back to the user.** One
   `withdrawCollateral(underlying, type(uint256).max, callerAddress)`.
   `type(uint256).max` is the documented "full balance" sentinel for
   `withdrawCollateral`. Residue = `pulledAmount - maxRepayment` lands
   directly at the user, never crossing the composer balance.

No `setFullCheckParams` entry. Debt is zero after the multicall; the
facade short-circuits the HF check (zero debt is always healthy). Adding
one would be no-op at best, and under some Gearbox configs a zero-debt
CA with residual collateral hints can misbehave in the check — safer to
omit.

### 5.4 Failure mode — pulled amount insufficient

If the user-signed quote went stale (tx pended long, interest drifted
past the buffer), `pulledAmount < maxRepayment` and step 3's
`_safeTransfer(ca → pool)` fails on insufficient CA balance. The whole
multicall reverts atomically. The user can re-quote with a larger
buffer and retry. Dust is not produced in either success or failure
branches — this is the guarantee the primitive provides.

### 5.6 Encoder helper

`CalldataLib.encodeGearboxRepayAll(underlying, pulledAmount, ca, facade, creditManager, quotedTokens)` produces the full sequence:

```
TRANSFER_FROM(user, composer, pulledAmount)
APPROVE(underlying, creditManager)
LENDING.GEARBOX_V3.REPAY[amount=UINT112_MASK, ca, facade, quotedTokens…]
```

`pulledAmount` is caller-computed off-chain (`calcDebtAndCollateral(ca, DEBT_ONLY)` → sum base + accrued + fees, multiply by `1 + bufferBps/10000`). The composer reads the post-transfer `balanceOf(this)` at execution time for the inner `addCollateral` amount; the encoder does not need to plumb the number twice.

### 5.5 Partial repay below `minDebt` — explicit rejection

Encoders that want "repay most, leave a bit open" must keep
`debt_after >= minDebt` by hand. The composer does not clamp on the
partial path (would require another `debtLimits()` read and a conditional
on-chain branch; we prefer the explicit-encoder-choice model). A partial
repay that would drop below `minDebt` reverts at the facade — surface it
in the integrator UI.

---

## 6. Borrow dust on the leverage path

Same discipline as full-repay, but simpler because the amounts are known
at encode time. In external-flash-loan leverage:

- Flash-loan: `flashAmt`.
- Borrow leg inside Gearbox: `increaseDebt(flashAmt + flashFee)` +
  `withdrawCollateral(underlying, flashAmt + flashFee, composer)`.
- Flash epilogue: repay `flashAmt + flashFee`.

The composer holds no residual underlying at the end of the callback.
If the caller oversizes the flash loan ("worst-case path"), the tail of
the composer tx sweeps any leftover to the user via the standard
`SWEEP(underlying, user)` op — same pattern as Fluid/Aave leverage.

---

## 7. What's not exposed

- `facade.multicall` entrypoint — composer is never the CA owner.
- `facade.closeCreditAccount` — same reason.
- `facade.liquidateCreditAccount*` — liquidation flows are a separate
  bot/liquidator track, not a borrower-side composer op.
- Adapter calls inside any multicall — see §1, no-adapters policy.
- On-demand price updates, `storeExpectedBalances` / `compareBalances` as
  primitive ops — only accessible via `GEARBOX_MULTICALL` with explicit
  encoder-supplied sub-calls.

---

## 8. Reference addresses

Gearbox V3 deploys one facade + one credit manager per credit suite
(underlying token × risk profile). There is no single "Gearbox address"
to hardcode per chain — encoders must pass `(facade, creditManager)`
explicitly per op. The ecosystem directory is at
<https://docs.gearbox.fi/>; for runtime discovery use
`DataCompressorV3` (see `gearbox-interfaces/IDataCompressorV3.sol`).
