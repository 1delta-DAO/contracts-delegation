# Morpho Midnight integration in the 1delta composer

Composer-side reference for Morpho **Midnight** — a fixed-rate, fixed-maturity, **order-book** lending
primitive. Midnight is **NOT a Morpho Blue fork**: there is no pool `supply` / `borrow`. Lending and
borrowing both happen through `take`, which consumes an off-chain-signed maker `Offer`
(lend = buy zero-coupon credit units, borrow = sell debt units). Position lifecycle is handled by
`supplyCollateral` / `withdrawCollateral` / `repay` / `withdraw` (credit redemption).

Source: [MidnightLending.sol](MidnightLending.sol). Flash loans: [../flashLoan/Midnight.sol](../flashLoan/Midnight.sol)
and the flash-loan security reference [../flashLoan/README.md](../flashLoan/README.md).

## What we expose

| Surface | LenderOp | Midnight fn | Direction |
| --- | --- | --- | --- |
| Supply collateral | `DEPOSIT` | `supplyCollateral` | inflow |
| Withdraw collateral | `WITHDRAW` | `withdrawCollateral` | **outflow** |
| Repay debt units | `REPAY` | `repay` | inflow |
| Redeem credit for loan token | `WITHDRAW_LENDING_TOKEN` | `withdraw` | **outflow** |
| Lend / borrow (order-book fill) | `MIDNIGHT_TAKE` (`14`) | `take` | debt-creating |
| Multi-token flash loan | `FlashLoanIds.MORPHO_MIDNIGHT` (`4`) | `flashLoan` | — |

There is no `BORROW` op: borrowing is selling debt units via `take`.

## Lender IDs

```
[ UP_TO_GEARBOX_V3 = 10000, UP_TO_MORPHO_MIDNIGHT = 11000 )   — all Midnight lending ops
```

## The security model — read this before anything else

Every Midnight entry-point takes the full `Market` struct (which embeds a dynamic
`CollateralParams[]` array) — and `Offer` / ratifier data originate off-chain — so, unlike the Morpho
Blue integration, the composer does **not** hand-pack the arguments. Instead the caller supplies the
**ABI-encoded argument tuple** (everything after the selector) and this module protects two things:

1. **It writes the selector itself.** The op is bound to a specific Midnight function, so a caller
   cannot swap in a different function that would shift which head word is the authorization field.
2. **It pins the authorization-critical head word on allowance-spending OUTFLOWS.** For
   `withdrawCollateral` / `withdraw` (and `take`'s `taker`), the composer overwrites `onBehalf` /
   `taker` with `callerAddress`, so a caller can only ever withdraw/borrow against **their own**
   Midnight position.

### Which head word is pinned vs. parameterized

| Op | Direction | `onBehalf` / `taker` | Rationale |
| --- | --- | --- | --- |
| `supplyCollateral` | inflow | **caller-parameterized** | crediting collateral to any position is benign (you only *give*) — matches the Morpho Blue supply convention |
| `repay` | inflow | **caller-parameterized** | repaying anyone's debt is benign (you only *shrink* debt) |
| `withdrawCollateral` | outflow | **pinned to `callerAddress`** | withdrawing collateral spends the position owner's allowance |
| `withdraw` (redeem credit) | outflow | **pinned to `callerAddress`** | redeeming credit units spends the owner's position |
| `take` | debt-creating | **`taker` pinned to `callerAddress`** | selling debt units creates a liability — must be the caller's own |

Only the handles that **spend the caller's allowance / position** carry `callerAddress`. This is the
same invariant every other lender in the module upholds; Midnight is on par with Aave / Compound /
Morpho / Silo here.

### Provider-side callbacks are forced to zero

`take` (`takerCallback`, head word 5) and `repay` (`callback`, head word 3) are overwritten with
`address(0)`. Midnight therefore pulls the loan token from `msg.sender` (the composer) and **never
invokes a caller-supplied Midnight-side callback** — closing a re-entrancy / fund-redirection vector.
Atomicity for the lend/borrow legs is provided by the surrounding flash loan, not a taker callback.

### External assumptions (must hold for correct + safe use)

- **Composer authorization.** The caller must have authorized the composer on Midnight
  (`setIsAuthorized`) for the position it operates on. The composer acts as the position manager;
  the on-chain `onBehalf`/`taker` pinning is what keeps that authority scoped to the caller.
- **Token approvals.** For the paying paths (`supplyCollateral` / `repay` / lending-side `take`,
  and flash-loan repayment) the composer must have approved Midnight for the relevant token, via a
  separate `APPROVE` compose op in the same batch (the flash-loan encoder prepends these).
- **`amount == 0` sentinels** resolve to the composer's current balance of the collateral/loan token
  at execution — the caller is responsible for ensuring the resolved amount is intended (e.g. `repay`
  reverts on Midnight if it exceeds the position debt).

## Per-op calldata layouts

All ops share the shape `midnight target(20) | … | argsLength(2) | ABI-encoded args`. The composer
writes the selector and injects/pins the head words noted above. `assets`/`units` head words are
injected at runtime (a zero header amount resolves to the composer's balance).

| Op | Header before args | Args tuple (ABI-encoded) | Injected / pinned |
| --- | --- | --- | --- |
| `supplyCollateral` | `midnight(20) \| collateralToken(20) \| assets(16) \| argsLen(2)` | `(Market, collateralIndex, assets, onBehalf)` | inject `assets`; `onBehalf` free |
| `withdrawCollateral` | `midnight(20) \| argsLen(2)` | `(Market, collateralIndex, assets, onBehalf, receiver)` | **pin `onBehalf`** |
| `repay` | `midnight(20) \| loanToken(20) \| units(16) \| argsLen(2)` | `(Market, units, onBehalf, callback, data)` | inject `units`; **zero `callback`**; `onBehalf` free |
| `withdraw` | `midnight(20) \| argsLen(2)` | `(Market, units, onBehalf, receiver)` | **pin `onBehalf`** |
| `take` | `midnight(20) \| argsLen(2)` | `(Offer, ratifierData, units, taker, receiver, takerCallback, takerCallbackData)` | **pin `taker`**; **zero `takerCallback`** |

Encoders: `CalldataLib.encodeMidnightSupplyCollateral / WithdrawCollateral / Repay / Withdraw / Take`
in [../../../utils/CalldataLib.sol](../../../utils/CalldataLib.sol).

## Flash loans

Midnight exposes a **multi-token** flash loan (`flashLoan(address[] tokens, uint256[] assets, address
callback, bytes data)`) wired through `FlashLoanIds.MORPHO_MIDNIGHT`. Because Midnight lets the caller
choose the callback target, the callback enforces **both** `caller() == MIDNIGHT` **and**
`initiator == address(this)` (self-initiation) before running compose ops — see
[../flashLoan/README.md](../flashLoan/README.md) for the full flash-loan trust model and why the
initiator check is mandatory for Midnight (it is the same shape as Aave V2/V3, not Morpho Blue).

Single-asset convenience: `CalldataLib.encodeMidnightFlashLoan(asset, amount, pool, poolId, data)`
mirrors the Morpho/Aave call shape; the multi-token form takes `tokens[]` / `amounts[]`.

## Tests

- [test/composer/lending/midnight/MidnightLending.t.sol](../../../../test/composer/lending/midnight/MidnightLending.t.sol)
  — mock-based unit suite (no fork; a faithful `MidnightMock` is `etch`-ed at the canonical instance).
  Covers: `onBehalf` relay on the inflows (supply/repay), `onBehalf`/`taker` pinning on the outflows
  (withdrawCollateral / withdraw / take), amount injection + zero-amount balance resolution,
  `callback` forced to zero, single- and multi-token flash-loan round-trips, and the flash-loan
  callback rejections (foreign caller, foreign initiator, unknown poolId).
- [test/composer/lending/midnight/MidnightMock.sol](../../../../test/composer/lending/midnight/MidnightMock.sol)
  — reproduces Midnight's exact selectors + token flows so the fund-path and pinning can be asserted.
