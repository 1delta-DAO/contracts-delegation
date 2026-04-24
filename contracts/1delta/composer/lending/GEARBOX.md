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

**The permission mask is not caller-chosen.** `BotListV3.setBotPermissions`
enforces `IBot(bot).requiredPermissions() == permissions` byte-for-byte
— any other value reverts with `IncorrectBotPermissionsException`. This
is Gearbox's way of saying "users don't scope bots; bots publish a
fixed permission surface and users opt into the whole thing."

The composer exposes `GearboxV3Lending.requiredPermissions()` returning:

```
COMPOSER_REQUIRED = ADD_COLLATERAL_PERMISSION       // bit 0
                  | INCREASE_DEBT_PERMISSION        // bit 1
                  | DECREASE_DEBT_PERMISSION        // bit 2
                  | WITHDRAW_COLLATERAL_PERMISSION  // bit 5
                  | UPDATE_QUOTA_PERMISSION         // bit 6
                  = 0x67
```

So the mask a user passes to `setBotPermissions` must be **exactly
`0x67`**. `SET_BOT_PERMISSIONS_PERMISSION` (bit 8) is excluded — bots
cannot escalate themselves. `EXTERNAL_CALLS_PERMISSION` (bit 16) is
omitted too — the composer never calls adapters inside a Gearbox
multicall (no-adapter policy, §1).

A consequence of the exact-match rule: there's no such thing as a
"supply-only" or "repay-only" composer grant at the Gearbox level. If
you want scope-limited delegation, deploy a separate bot wrapper that
returns a smaller `requiredPermissions()` — but that's a separate
integration from this composer.

### 2.2 Revocation — symmetric, owner-only

Same shape as grant; the mask is zero:

```solidity
calls[0] = abi.encodeCall(
    ICreditFacadeV3Multicall.setBotPermissions,
    (composer, 0)
);
ICreditFacadeV3(facade).multicall(ca, calls);
```

### 2.3 Caller authentication — composer-side

Gearbox only asks "is the bot registered on this CA with the right
permissions?" — it does not check *who invoked the bot*. Without an
additional check on the composer side, any caller who knows a bot-
enabled CA address could call `deltaCompose` with that CA as target and
drain it via `increaseDebt` + `withdrawCollateral`.

Every composer primitive that relays into `botMulticall` therefore
includes a mandatory auth step that derives the entire address chain
from a single caller-supplied root — the credit account:

```solidity
creditManager = ICreditAccountV3(creditAccount).creditManager()   // immutable in CreditAccountV3
creditFacade  = ICreditManagerV3(creditManager).creditFacade()    // from CreditManagerV3
borrower      = ICreditManagerV3(creditManager).getBorrowerOrRevert(creditAccount)
if borrower != callerAddress  →  revert InvalidCaller()
```

`callerAddress` is the authenticated `deltaCompose` caller (either
`msg.sender` or, inside a flash-loan callback, the validated initiator).

**Why the chain is rooted at `creditAccount`, with CM and facade both
derived on-chain.** Calldata for every Gearbox primitive carries
*only* `creditAccount`; CM and facade are never taken from the user.
This closes every calldata-injection vector on the auth path:

- **Real CA**: `creditAccount.creditManager()` returns the real CM.
  `real_CM.getBorrowerOrRevert(ca)` returns the real borrower. A
  non-borrower caller fails the equality check — revert.

- **Fake CA (attacker contract) reporting real CM**: the real CM's
  `getBorrowerOrRevert(fakeCA)` reverts — `fakeCA` is not in the CM's
  registry. Revert.

- **Fake CA reporting fake CM (both attacker-controlled)**: auth passes
  via lies, but *dispatch* goes to `fake_CM.creditFacade() = fake_facade`
  — an attacker contract running as `msg.sender = composer`. It cannot
  touch any real CA on real Gearbox (bot permissions are keyed on
  `(composer, realCM, borrower)` in `BotListV3`) and cannot spend the
  composer's max approvals (those are only granted to legitimate CM
  addresses, not attacker-picked spenders). Attacker runs a pointless
  gas-burner against themselves.

- **Victim CA impersonation**: not exploitable. CAs are deterministic
  clones from Gearbox's `AccountFactory`; an attacker cannot deploy code
  at a victim CA's address.

**Approval parameter.** The encoders still take `creditManager` as an
argument, used solely for the prepended `APPROVE(underlying,
creditManager)` hop. It is never used for auth — the composer derives
its own CM on-chain. A caller who passes the wrong CM would grant the
wrong spender, and the subsequent real-facade call would fail on
`transferFrom` — a self-grief, not an attack vector.

`openCreditAccount` (kind=1 of `GEARBOX_MULTICALL`) is the single
exception: there's no pre-existing CA to root the chain on, so the
caller supplies the facade directly. This is safe because (a) Gearbox's
open entrypoint has no caller check and (b) the composer hard-pins
`onBehalfOf = callerAddress` inside the builder — the caller cannot
open a CA owned by anyone else.

**Governance-rotation edge case.** `creditManager.creditFacade()` reads
the currently-bound facade, which Gearbox's `CreditConfiguratorV3` can
swap via `setCreditFacade(newFacade, migrateParams)`. Rotation is a
governance op, not mid-tx manipulable — the composer always reads the
facade Gearbox itself would route through at the same tx.

### 2.4 Attack vectors considered

The composer's bot role on every user's CA is the whole business model —
once a victim grants the composer the full mask, the composer can
unilaterally move their funds as far as Gearbox is concerned. Everything
below is about making sure only the victim can tell the composer to do
that. Each row is a distinct attack path that was analyzed; the
"Mitigation" column is the property actually enforced in code.

| # | Vector | Where | Mitigation |
|---|---|---|---|
| A1 | **Impersonated caller.** Mallory knows Alice's CA address, calls `deltaCompose` with Alice's CA + withdraw-to-Mallory. Without a composer-side check, Gearbox's own auth accepts the call because the composer is a valid bot on Alice's CA. | Every primitive that relays `botMulticall`. | `_gearboxAuthCaller` rejects unless `callerAddress == borrower(ca)`, where `borrower` comes from the CA's real CM (derived via `creditAccount.creditManager()`). Covered by `test_gearboxV3_unauthorized_caller_cannot_drain_ca`. |
| A2 | **CM spoofing via calldata.** Historical bug: the composer used to accept `creditManager` from calldata. Mallory could pair Alice's real CA + real facade with a fake CM returning Mallory as borrower for every CA, bypassing A1 while dispatch still hit real Gearbox. | Pre-fix `_gearboxAuthCaller`. | Calldata no longer carries a CM field. The composer reads `creditManager := creditAccount.creditManager()` on-chain. |
| A3 | **Facade spoofing via calldata.** After A2 was fixed by `creditManager := facade.creditManager()`, an attacker could still supply a fake facade whose lying `creditManager()` returned a lying CM — the attacker-picked facade was then also the dispatch target. | Pre-CA-rooted-chain `_gearboxAuthCaller`. | Calldata no longer carries a facade field for bot ops either. The composer reads `creditFacade := creditManager.creditFacade()` on-chain, chained from the CM that was itself chained from the CA. Only `creditAccount` is caller-supplied; an attacker-picked CA either resolves to the real chain (auth rejects non-borrowers) or points into a fully-attacker chain with no reach into real Gearbox. Covered by `test_gearboxV3_fake_ca_cannot_drain_real_ca`. |
| A4 | **`openCreditAccount` ownership spoof.** Mallory calls the generic multicall with `kind=1` and tries to supply `onBehalfOf = alice` so a new CA is opened in Alice's name. | `_gearboxRelayOpen`. | `onBehalfOf` is hard-pinned to `callerAddress` in the builder (`mstore(add(ptr, 0x04), callerAddress)`); the calldata layout has no `onBehalfOf` field at all. Encoder cannot supply it. |
| A5 | **Bot-permission escalation.** Composer calls `setBotPermissions` on a CA as the bot, granting itself `EXTERNAL_CALLS` or broadening the mask. | Gearbox-side. | `requiredPermissions()` omits `SET_BOT_PERMISSIONS_PERMISSION` (bit 8) and `EXTERNAL_CALLS_PERMISSION` (bit 16). `BotListV3.setBotPermissions` enforces `IBot(bot).requiredPermissions() == permissions` exactly, so users cannot accidentally grant either bit, and the composer cannot escalate itself. |
| A6 | **Adapter pivot.** Encoder slips a `MultiCall.target` pointing at a Gearbox adapter or an unrelated contract through `_gearboxMulticall` to escape the facade-only invariant. | `_gearboxRelayBotMulticall` / `_gearboxRelayOpen` sub-call assembly. | Every sub-call's `target` is hard-coded to the derived `creditFacade`; the encoder supplies only inner calldata. No-adapter policy in code. |
| A7 | **Flash-loan callback caller spoof.** Inside a flash callback, `_deltaComposeInternal` runs with a `callerAddress` taken from callback calldata — if that address is attacker-controlled, it bypasses A1 entirely. | All flash callback callbacks across chains. | Flash callbacks validate the initiator (`pool`/`vault` is the expected flash provider, initiator matches the stashed originator) before forwarding into `_deltaComposeInternal`. Non-Gearbox concern; documented in the `flashLoan/` callback modules. |
| A8 | **Bot globally forbidden mid-transaction.** Gearbox governance calls `setBotForbiddenStatus(composer, true)`; every existing user's `botMulticall` now reverts. Does not drain anyone, but strands positions. | Gearbox-side, external. | Not a drain vector — documented as a recovery path in §2.5 (below). |
| A9 | **Reentrancy into `deltaCompose` via fake facade/CA.** A fake contract run as `msg.sender = composer` re-enters `deltaCompose`; the re-entry runs with `callerAddress = composer`. | `BaseComposer.deltaCompose` (no `nonReentrant`). | `ComposerLite` carries `nonReentrant`. `BaseComposer` does not, but the composer holds no persistent fund state (max approvals are only to real protocols; any transient balance inside a single outer call belongs to the outer `callerAddress`), so a re-entry with `callerAddress = composer` has nothing to drain. Revisit if the composer ever starts holding state keyed on `msg.sender`. |
| A10 | **Approval hijack via fake creditManager in APPROVE op.** Mallory emits an encoder-style `APPROVE(token, attackerAddress)` then a Gearbox primitive — composer grants an attacker max allowance of whatever token is transient. | `_approve` in `AssetTransfers`. | Approvals are durable by design (composer holds no funds between txs, per project policy). In-tx, `APPROVE` is an explicit composer op the caller signs for — Mallory can only set approvals with Mallory's own tokens, not Alice's. Alice's tokens are never transiently held without Alice initiating the `deltaCompose`. |
| A11 | **Zero-calls multicall waste / shape confusion.** Caller submits `_gearboxMulticall` with `numCalls = 0` — an empty botMulticall or an `openCreditAccount` with no inner ops (creates an empty CA). Not a drain vector, but a gas-waste / accidental-state trap. | `_gearboxMulticall`. | Guard rejects both: `if (kind > 1 || numCalls == 0) _invalidOperation();` — happens before auth, so it's a cheap early exit. Covered by `test_gearboxV3_bot_multicall_zero_calls_reverts` and `test_gearboxV3_open_credit_account_zero_calls_reverts`. |

The canonical invariant linking A1–A3: **every address on the auth path
is derived on-chain from the single caller-supplied `creditAccount`
root.** An attacker controlling one input cannot split the chain —
choosing a real CA means real auth (rejects non-borrowers), choosing a
fake CA means the whole chain lives in attacker-land (no reach into
real Gearbox, no ability to spend composer approvals that are keyed on
real CMs).

### 2.5 Global bot ban recovery

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

**No calldata field anywhere names the `creditFacade` directly** (except
the `openCreditAccount` shape, §3.2): the composer derives CM and facade
on-chain from `creditAccount` via `creditAccount.creditManager()` +
`creditManager.creditFacade()`. See §2.3.

#### `DEPOSIT` (`_depositToGearboxV3`)

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 20 | underlying |
| 20 | 16 | amount (0 = use composer balance) |
| 36 | 20 | creditAccount |

Emits `facade.botMulticall(ca, [addCollateral(underlying, amount)])`.
The facade's default HF ≥ 1.0 check runs at the end; callers who want
a user-signed buffer should use `GEARBOX_MULTICALL` with an explicit
`setFullCheckParams` sub-call. Token must be pre-approved to the
CreditManager (encoder emits one `APPROVE` op in front).

#### `BORROW` (`_borrowFromGearboxV3`)

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 20 | underlying (must equal the pool's underlying) |
| 20 | 16 | amount |
| 36 | 20 | receiver |
| 56 | 20 | creditAccount |

Emits `botMulticall(ca, [increaseDebt(amount), withdrawCollateral(underlying, amount, receiver)])`.

HF buffer is not a primitive-level concern — Gearbox's facade enforces
HF ≥ 1.0 by default. A borrow that lands at exactly HF = 1.0 is a
liquidation waiting on the next oracle tick, so callers that want a
user-signed buffer should use `GEARBOX_MULTICALL` with an explicit
`setFullCheckParams` sub-call at the tail.

#### `REPAY` (`_repayToGearboxV3`)

Three shapes, discriminated by `amount`. Common calldata header:

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 20 | underlying |
| 20 | 16 | amount |
| 36 | 20 | creditAccount |
| 56 | 1 | numQuotedTokens (N — only meaningful for safe-max) |
| 57 | N × 20 | quotedTokens[] (only consumed when amount == UINT112_MASK) |

**Zero-means-balance (`amount == 0`, `numQuoted == 0`)** — matches the
convention used by the other lenders (Aave, Morpho, etc.). The composer
substitutes `balanceOf(composer, underlying)` for the amount, then
falls through to the literal-partial path. Use when the caller wants
"repay with whatever I just transferred in" without needing a debt
read.

**Explicit literal (`amount ∈ (0, UINT112_MASK)`, `numQuoted == 0`)** —
emits `botMulticall(ca, [addCollateral(underlying, amount),
decreaseDebt(amount)])` with the supplied amount. Caller owns
responsibility for avoiding the `(0, minDebt)` remainder window.

**Safe max (`amount == UINT112_MASK`, `numQuoted ≥ 0`)** — "repay as
much as possible, safely". The composer reads `maxRepay` via
`calcDebtAndCollateral(ca, DEBT_ONLY)` (= `debt + accruedInterest +
accruedFees`) and computes `amt = min(balanceOf(composer), maxRepay)`.
Then branches:

- `amt == maxRepay && numQuoted > 0` → full close-out:
  `botMulticall(ca, [updateQuota(tok, int96.min, 0) × N,
  addCollateral(underlying, maxRepay), decreaseDebt(uint256.max)])`.
  Exact deposit; **no trailing `withdrawCollateral(max)` sweep** (the
  previous full-repay path reverted with `AmountCantBeZeroException`
  when the CA had been drained of underlying — the realistic leverage-
  close state). Surplus (if `bal > maxRepay`) stays on the composer for
  explicit sweep via a `TRANSFER` op — integrates cleanly with flash-
  close flows that consume the surplus for flash repayment.
- otherwise → partial: `botMulticall(ca, [addCollateral(underlying, amt),
  decreaseDebt(amt)])`. No quota strip. If the caller supplied
  `quotedTokens` but composer balance was short, the list is ignored —
  the primitive prefers executing a partial over reverting. This is the
  "100 wei short of a 100k repay — still do the 99.9k" property that
  motivates the combined shape.

The safe-max path may still revert if the resulting remainder lands in
Gearbox's `(0, minDebt)` window (same policy as the Lista lender path;
UI is expected to warn based on `minDebt`). It also reverts with
`DebtToZeroWithActiveQuotasException` if `bal ≥ maxRepay` but
`numQuoted == 0` and the CA has active quotas (caller error — should
have supplied `quotedTokens`).

See §5 for the close-out rationale.

#### `WITHDRAW` (`_withdrawFromGearboxV3`)

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 20 | token |
| 20 | 16 | amount (UINT112_MASK = withdraw all) |
| 36 | 20 | receiver |
| 56 | 20 | creditAccount |

Emits `botMulticall(ca, [withdrawCollateral(token, amountOrMax, receiver)])`.
HF buffer handled by facade default; callers who want a user-signed
buffer should use `GEARBOX_MULTICALL` with an explicit
`setFullCheckParams` sub-call.

`UINT112_MASK` is translated to `type(uint256).max` for the
`withdrawCollateral` argument (Gearbox's own "sweep full balance" sentinel).

### 3.2 Generic multicall (`GEARBOX_MULTICALL`)

Dispatched on `lendingOperation == LenderOps.GEARBOX_MULTICALL` and
`lender ∈ [UP_TO_FLUID_SMART, UP_TO_GEARBOX_V3)`. Calldata:

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 1 | kind (0 = `botMulticall`, 1 = `openCreditAccount`) |
| 1 | 20 | **kind=0:** creditAccount (CM + facade derived via CA→CM→facade) — **kind=1:** creditFacade (no CA yet, so caller supplies it) |
| 21 | 20 | padding (unused in both kinds) |
| 41 | 32 | referralCode (kind=1) or padding (kind=0) |
| 73 | 2 | numCalls (N — **must be > 0**; `N == 0` reverts `InvalidOperation`) |
| 75 | Σ (2 + len) | N sub-calls, each `innerLen (2) | innerCalldata (innerLen)` |

`kind=2` (closeCreditAccount) is reserved but unreachable (composer is
not the CA owner); the dispatcher rejects it. The same guard also
rejects `numCalls == 0`, so empty-multicall shapes (which would either
spin an empty Gearbox call or open an empty CA) are caught at dispatch
before auth.

Every sub-call's `target` is implicitly the derived `creditFacade` —
the encoder does **not** supply per-sub-call targets, and the composer
hard-codes the derived facade. This is the no-adapters policy in code.

For `kind=1` (`openCreditAccount`), `onBehalfOf` is **always**
`callerAddress` (the authenticated `deltaCompose` caller). The encoder
cannot spoof a different `onBehalfOf`. This prevents an attacker from
opening unauthorized CAs owned by other users via a third-party-
submitted composer call. `kind=1` is the one place where the caller
supplies the facade directly (there's no CA yet to derive from) —
safe because (a) Gearbox's open entrypoint has no caller check, and
(b) the composer pins `onBehalfOf` regardless of which facade
address is passed, so a malicious facade can only run attacker logic
as the composer (no victim CA reach).

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

## 5. Repay — safe-max semantics

The `REPAY` op's **safe-max shape** (`amount == UINT112_MASK`) is the
one primitive that deliberately diverges from "one shot, no on-chain
reads." It executes a single on-chain debt read, then degrades
gracefully between close-out and partial based on what funds actually
permit at execution time. The two goals, both motivated by real failure
modes in earlier implementations:

1. **No arithmetic reverts on funding shortfalls.** "Pay 99.9k of a
   100k debt when the swap came up 100 wei short" should execute, not
   revert. Callers who are 100 wei short are not attackers and should
   not need to retry.
2. **Dust-safe close-out on drained CAs.** Leverage-close flows start
   with the borrowed underlying already deployed out of the CA. The
   pre-safe-max full-repay emitted a trailing `withdrawCollateral(max)`
   sweep that reverted with `AmountCantBeZeroException` when the CA had
   no underlying to sweep. Safe-max drops the sweep; residue (if any)
   stays on the composer.

### 5.1 Key invariant — Gearbox caps `decreaseDebt` internally

`CreditManagerV3.manageDebt` (the only consumer of `decreaseDebt`
arguments) does this, in order:

```
maxRepayment = _amountWithFee(totalDebt);       // totalDebt = debt + accruedInterest + accruedFees
if (amount >= maxRepayment) amount = maxRepayment;
_safeTransfer(creditAccount → pool, amount);    // CA must hold `amount`
// … debt zeroed when amount == maxRepayment
```

So passing `type(uint256).max` as the `decreaseDebt` argument is safe
and zeros the debt atomically — but only if the CA already holds
`maxRepayment` of underlying. Safe-max ensures this by reading
`maxRepayment` on-chain via `calcDebtAndCollateral(DEBT_ONLY)` in the
same tx as the `botMulticall`, then depositing exactly that amount via
`addCollateral` before `decreaseDebt(max)`.

### 5.2 The safe-max recipe (all inside one `botMulticall`)

0. **Off-chain, encoder side.** For close-out intent, enumerate the
   CA's currently-enabled quoted tokens —
   `CreditManagerV3.enabledTokensMask(ca) & CreditManagerV3.quotedTokensMask()`
   — and pass the list in calldata. For partial/delever intent, pass
   an empty list. The composer does not iterate on-chain.

1. **Pull underlying from the user** (prepended `TRANSFER_FROM` op).
   For close-out, pull at least `maxRepayment` (compute off-chain via
   `calcDebtAndCollateral(ca, DEBT_ONLY)`; a 1% buffer covers in-tx
   accrual). For a partial, pull whatever amount the caller wants to
   repay.

2. **Composer reads `maxRepay` on-chain** at dispatch, computes
   `amt = min(balanceOf(composer), maxRepay)`, and branches:

   **Close-out branch** — triggered when `amt == maxRepay && numQuoted > 0`:
   - `updateQuota(tok_i, type(int96).min, 0)` for each of the N quoted
     tokens — Gearbox's "fully disable" sentinel. Settles accrued quota
     interest into `maxRepayment`.
   - `addCollateral(underlying, maxRepay)` — exact deposit.
   - `decreaseDebt(type(uint256).max)` — CM caps to the exact
     `maxRepayment`. Debt goes to zero atomically.
   - **No trailing `withdrawCollateral` sweep.** Deposit was exact;
     nothing left on the CA to sweep. Surplus (if `bal > maxRepay`)
     stays on the composer — integrates cleanly with flash-close flows
     that consume it for flash repayment.

   **Partial branch** — triggered otherwise (funds short for close, or
   caller supplied an empty `quotedTokens`):
   - `addCollateral(underlying, amt)` — deposit exactly the clamped
     amount.
   - `decreaseDebt(amt)` — literal, not max. Reduces debt by `amt`.
   - No quota strip. If the caller supplied `quotedTokens` but funds
     were short, the list is ignored — the primitive prefers executing
     a partial over reverting.

### 5.3 Failure modes

Most funding-arithmetic situations that used to revert now execute as
partials. The remaining genuine revert modes are:

- **`(0, minDebt)` window.** If the partial remainder lands in the
  forbidden range, the facade reverts with
  `BorrowAmountOutOfLimitsException`. Same policy as the Lista lender
  path — UI is expected to warn users based on the pool's `minDebt`.
- **Zero debt with active quotas.** If `bal ≥ maxRepay` but
  `numQuoted == 0` AND the CA has active quotas enabled, the partial
  branch would drive debt to zero while quotas remain, reverting with
  `DebtToZeroWithActiveQuotasException`. Caller error — should use
  `encodeGearboxV3RepayAll(..., quotedTokens)` with the list.
- **Composer balance zero.** Nothing to repay; the primitive reverts
  with `InvalidOperation` (composer-side — nothing for the caller to
  retry with).

### 5.4 Encoders

Three encoder entrypoints, all packing into the standard `LenderOps.REPAY`
op:

- `encodeGearboxV3RepayPartial(underlying, amount, ca, creditManager)`
  — explicit literal. `amount ∈ (0, UINT112_MASK)`. Caller owns minDebt
  arithmetic.
- `encodeGearboxV3RepayPartialMax(underlying, ca, creditManager)` —
  safe-max with `numQuoted == 0`. Always degrades to partial; never
  closes. For delever / liquidation-prevention flows.
- `encodeGearboxV3RepayAll(underlying, ca, creditManager, quotedTokens)`
  — safe-max with the quoted list. Closes if funds permit; degrades to
  partial otherwise.

All three prepend an `APPROVE(underlying, creditManager)` hop. The
`creditManager` argument is *only* used for that approve — the composer
derives its own CM on-chain from the CA for auth and the debt read.

### 5.5 Flash-loan close-out composition

```
deltaCompose([
    FLASH_LOAN(flashProvider, X, [
        // callback body:
        // optional: withdraw collateral, swap to underlying, etc.
        TRANSFER_FROM(user, composer, pulledAmount)       // or flash-borrowed amount
        APPROVE(underlying, creditManager)
        LENDING.GEARBOX_V3.REPAY[amount=UINT112_MASK, ca, quotedTokens=[...]]
        // flash repay happens in the flash-loan epilogue — consumes composer surplus
    ])
])
```

Sizing rule: the total amount delivered to the composer inside the
callback must be `≥ maxRepayment + flashFee` for a clean close (close
consumes `maxRepayment`, flash epilogue consumes `flashFee` from
surplus). Under-delivery: close degrades to partial, flash epilogue
may or may not still find enough surplus — if not, the whole tx
reverts (no stuck state).

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

## 6.5 Gearbox quirks that surface in integration

A handful of Gearbox invariants are not encoder-visible but will bite a
caller that mixes ops incautiously. Calling them out so they don't
surprise anyone during integration:

**Debt updates are once-per-block per CA.** `increaseDebt` /
`decreaseDebt` revert with `DebtUpdatedTwiceInOneBlockException` if the
same CA already had a debt change in the current block. Practical
consequences:
- After `openCreditAccount(…, [addCollateral, increaseDebt, …])`, the
  same block cannot run another `increaseDebt` or `decreaseDebt` on
  that CA. Any flow that opens-then-borrows-more must span blocks.
- Leverage loops that want to stack debt atomically need to use a
  single multicall with a single `increaseDebt` (plus adapter swaps) —
  but we don't use adapters, so multi-step leverage must go through
  the external flash-loan path (§4.3), not Gearbox's own.

**`updateQuota` requires non-zero debt.** Calling `updateQuota` on a
zero-debt CA reverts with `UpdateQuotaOnZeroDebtAccountException`.
Correct ordering inside `openCreditAccount` is therefore:
1. `addCollateral(token, amount)`
2. `increaseDebt(…)`                — creates the debt
3. `updateQuota(token, quota, 0)`   — now legal
4. `setFullCheckParams(…)`          — final HF check with collateral counted

The composer's `_repayGearboxV3Full` does the reverse (quota-strip
before `decreaseDebt`) because pre-repay debt > 0, so the
zero-debt-account constraint only bites on opens.

**`withdrawCollateral(token, type(uint256).max, to)` leaves 1 wei
behind on the CA.** Gearbox's facade does a deliberate
`--amount` if the pre-sweep balance ≥ 1 (warm-slot optimization; see
`CreditFacadeV3._withdrawCollateral` in core-v3). That 1 wei is not
dust the composer produced — it's a protocol invariant. Tests that
assert "CA holds 0 of underlying after full close" must allow the 1
wei sentinel. The dust-safe repay flow (§5) still holds: no residue
the composer *caused* is left anywhere.

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
to hardcode per chain — encoders pass `creditAccount` on every bot op
(the composer derives CM and facade via the CA→CM→facade chain
on-chain). `creditManager` still needs to be passed separately to the
encoder for the prepended `APPROVE(token, cm)` hop on DEPOSIT/REPAY —
the composer doesn't use it for auth, only for allowance setup.
`openCreditAccount` (kind=1 of `GEARBOX_MULTICALL`) takes the facade
directly in calldata because there's no pre-existing CA to root the
chain on. The ecosystem directory is at <https://docs.gearbox.fi/>;
for runtime discovery use `DataCompressorV3` (see
`gearbox-interfaces/IDataCompressorV3.sol`).
