# Flash loans in the 1delta composer

Reference + **security model** for every flash-loan variant the composer initiates. The files in this
directory are the **initiators** (they build and fire the provider's flash call); the matching
**callbacks** are chain-specific and generated under
[`../chains/<chain>/flashLoan/callbacks/`](../chains). One aggregator, `UniversalFlashLoan`, routes a
single `ComposerCommands.FLASH_LOAN` op to the right initiator by a leading `flashLoanType` byte.

| `FlashLoanIds` | Initiator | Callback family |
| ---: | --- | --- |
| `MORPHO = 0` | [Morpho.sol](Morpho.sol) | callback-to-`msg.sender` |
| `UNISWAP_V3 = 1` | [UniswapV3.sol](UniswapV3.sol) | callback-to-`msg.sender` (CREATE2-derived pool) |
| `AAVE_V3 = 2` | [AaveV3.sol](AaveV3.sol) | callback-to-**arbitrary receiver** |
| `AAVE_V2 = 3` | [AaveV2.sol](AaveV2.sol) | callback-to-**arbitrary receiver** |
| `MORPHO_MIDNIGHT = 4` | [Midnight.sol](Midnight.sol) | callback-to-**arbitrary callback** |

Related flash-loan-shaped providers that are **not** routed through `UniversalFlashLoan` (they use a
singleton `unlock` or a Morpho-fork callback) are covered in [§ Singleton & fork providers](#singleton--fork-providers).

---

## The core invariant

Inside a flash loan the callback **re-enters the composer** and runs arbitrary compose operations with
an authenticated `callerAddress` (a.k.a. `origCaller`) — the user whose funds and positions those ops
may move. That `origCaller` is trusted for exactly one reason:

> **The composer's own initiator prepended it.** Each initiator here splices `callerAddress` (the
> authenticated caller of the top-level `deltaCompose`) as the first 20 bytes of the `data` echoed by
> the provider. The callback slices those 20 bytes back off and runs compose ops as that address.

If an attacker could reach a callback with an **attacker-chosen** `origCaller`, they would impersonate
any victim (spend approvals, drain positions). So **every callback must prove self-initiation** before
trusting the sliced `origCaller`. There are two ways a provider can be tricked into calling our
callback, and therefore two required defenses.

### Family 1 — callback-to-`msg.sender` (self-initiation is inherent)

Morpho, Uniswap V3, Balancer V3 (`unlock`), Uniswap V4 (`unlock`), and Moolah all invoke the callback
**on the address that initiated the flash** — never on an arbitrary parameter. So a callback is only
ever reached if **we** called the provider. Validating that the *caller* is the trusted provider is
sufficient:

- **Morpho / Moolah**: `caller() == <knownInstance>` selected by `poolId` (see below).
- **Uniswap V3**: recompute the pool's CREATE2 address from `(factory, token0, token1, fee)` and require
  `caller()` to equal it — trusts any immutable, factory-deployed pool without a per-pool allowlist.
  An attacker cannot place code at a trusted-factory CREATE2 address, so no forged caller passes.
- **Balancer V3 / Uniswap V4**: `caller() == <singleton>` (the Vault / PoolManager).

An attacker calling the provider directly (e.g. `pool.flash(composer, …)`) gets the provider calling
back the **attacker**, not the composer — so the composer's callback is never reached.

### Family 2 — callback-to-arbitrary-address (self-initiation MUST be checked)

**Aave V2, Aave V3, and Midnight** take the callback target as a **call parameter**
(`flashLoan(receiver, …)` / `flashLoan(tokens, assets, callback, data)`) and pass `msg.sender` as an
`initiator` argument. Anyone can call the provider with `callback = composer` and **fully
attacker-controlled `data`** (including a spoofed `origCaller`). For these, `caller() == pool` is
**not enough** — the callback must additionally require:

```
initiator == address(this)   // the composer must have initiated this loan
```

Because the provider sets `initiator = msg.sender` of the `flashLoan` call, requiring it to equal the
composer proves the loan was self-initiated and thus that `origCaller` was attached by our own
initiator. A direct attacker call has `initiator = attacker` → revert.

> **Midnight footnote (critical).** Midnight looks Morpho-flavored but is Family 2 — it honors an
> arbitrary `callback` parameter. `caller() == MIDNIGHT` alone would let anyone drive the callback with
> a spoofed `origCaller`; the `initiator == address(this)` check is what closes it. This mirrors the
> Aave V2/V3 callbacks exactly. (This was a real bug that is now fixed + regression-tested.)

### Summary

| Provider | Callback reaches | Required checks |
| --- | --- | --- |
| Morpho | `msg.sender` | `caller() == knownInstance[poolId]` |
| Moolah (Lista) | `msg.sender` | `caller() == LISTA_DAO[poolId]` |
| Uniswap V3 | `msg.sender` | `caller() == CREATE2(factory[forkId], tokens, fee)` |
| Balancer V3 / Uni V4 | `msg.sender` | `caller() == singleton` |
| Aave V2 | arbitrary `receiver` | `caller() == pool[poolId]` **and** `initiator == self` |
| Aave V3 | arbitrary `receiver` | `caller() == pool[poolId]` **and** `initiator == self` |
| **Midnight** | arbitrary `callback` | `caller() == MIDNIGHT[poolId]` **and** `initiator == self` |

## `poolId` / `forkId` — instance selection

The first byte of the echoed `params` is a **`poolId`** (for Morpho / Aave / Moolah / Midnight) that a
`switch` in the callback maps to a specific, hardcoded provider address to compare `caller()` against.
Uniswap V3 instead carries a **`forkId`** that selects the `(factory, initCodeHash)` pair used for the
CREATE2 re-derivation. **An unrecognized `poolId` / `forkId` reverts** (`INVALID_FLASH_LOAN` / `BAD_POOL`)
— only vetted instances are accepted. The initiators accept *any* `pool` address from calldata as the
call target, but a non-canonical target simply fails the callback's `caller()` check and reverts, so
the target field is inert for security.

The generated factory/instance constants for Uniswap V3 are pinned to `@1delta/dex-registry` by
[`scripts/_create/verifyUniV3FlashConstants.ts`](../../../../scripts/_create/verifyUniV3FlashConstants.ts)
(CI `verify-generated`), which catches stale/copy-paste errors across all chains.

## Repayment

The composed operations executed inside the callback must return principal (+ fee/premium):

- **Morpho / Midnight / Aave**: the provider **pulls** repayment via `transferFrom(composer, …)` after
  the callback, so the compose ops must leave the borrowed amount **approved** to the provider. The
  Midnight and Aave encoders prepend the required `APPROVE` ops; over-borrow/short-repay reverts the
  whole transaction inside the provider.
- **Uniswap V3**: the compose ops must **transfer** principal + fee back to the pool; the pool checks
  its balance after the callback and reverts otherwise. No approval is used.

Repayment enforcement lives in the provider, not the composer — an attacker cannot use a flash loan to
leave the composer short, and cannot skip repayment.

## Initiator calldata layouts

Single-asset providers share `asset(20) | pool(20) | amount(16) | paramsLength(2) | params`, where the
initiator prepends `callerAddress(20)` ahead of `params` (= `poolId(1) | composeOps`):

| Provider | Body after `flashLoanType` |
| --- | --- |
| Morpho / Aave V2 / Aave V3 | `asset(20) \| pool(20) \| amount(16) \| paramsLen(2) \| params` |
| Uniswap V3 | `forkId(1) \| pool(20) \| tokenIn(20) \| tokenOut(20) \| fee(2) \| amount0(16) \| amount1(16) \| paramsLen(2) \| params` |
| Midnight (multi-token) | `pool(20) \| numTokens(1) \| [token(20)+amount(16)]×n \| paramsLen(2) \| params` |

Echoed `data` seen by the callback is always `origCaller(20) | poolId(1) | composeOps` (Uniswap V3
carries `origCaller(20) | tokenIn(20) | tokenOut(20) | forkId(1) | fee(2) | composeLen(2) | composeOps`).

Encoders: `CalldataLib.encodeFlashLoan` (Morpho/Aave, single-asset), `encodeUniswapV3FlashLoan`,
`encodeMidnightFlashLoan` (single- and multi-asset). See [../../../utils/CalldataLib.sol](../../../utils/CalldataLib.sol).

## Re-entrancy

The full composer intentionally has **no `nonReentrant` guard** — flash/swap callbacks *must* re-enter
`_deltaComposeInternal`. This is safe because `callerAddress` is re-authenticated on every entry (it is
never re-derived from attacker calldata), and every fund-moving op is scoped to it: transfers pin
`from = callerAddress`, lending outflows pin the position owner. A re-entrant untrusted target can at
worst sweep the caller's **own** mid-batch funds (the composer holds no funds between transactions);
no other user's funds are reachable. Same-provider re-entry (e.g. re-entering the same Uniswap V3 pool)
is additionally blocked by the provider's own lock.

## Singleton & fork providers

These are flash-loan-shaped but reached differently:

- **Balancer V3** (`balancerUnlockCallback`) and **Uniswap V4** (`unlockCallback`) — driven by the
  singleton `unlock` (take / sync / settle inside the callback). Family 1: `caller() == singleton`.
  See [../singletons/](../singletons) and the swap-callback dirs `../chains/<chain>/flashSwap/callbacks/`.
- **Moolah (Lista)** (`onMoolah*`) — a Morpho-Blue-style provider available on some chains
  (`caller() == LISTA_DAO`). Family 1.

Their callbacks live alongside the flash-loan callbacks under `../chains/<chain>/flashLoan/callbacks/`
and `../chains/<chain>/flashSwap/callbacks/`.

## Tests

- [test/composer/lending/flashloans/UniV3FlashLoanSafety.t.sol](../../../../test/composer/lending/flashloans/UniV3FlashLoanSafety.t.sol)
  — Base fork; valid Uniswap + Pancake loans, and rejection of unauthorized caller / spoofed tokens /
  unknown forkId / same-pool re-entry.
- [test/composer/lending/callbacks/aaveV3/](../../../../test/composer/lending/callbacks/aaveV3) and
  `aaveV2/` — per-chain mock callbacks asserting `caller() == pool` **and** `initiator == self`.
- [test/composer/lending/midnight/MidnightLending.t.sol](../../../../test/composer/lending/midnight/MidnightLending.t.sol)
  — Midnight flash round-trips + callback rejections (foreign caller, **foreign initiator**, unknown
  poolId); the foreign-initiator test is load-bearing (fails without the `initiator == self` check).
