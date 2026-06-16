# Callback Trust Assessment — Hemi flash-loan callbacks

Fully-annotated worked example for the per-callback "which addresses do we trust, and why is that
safe" assessment. Every other chain's `callbacks/TRUST.md` is the auto-generated short form of
this and points back here for the reasoning and the generalisable criteria.

## Why a wrong trusted address is catastrophic

A flash-loan/unlock callback re-enters `_deltaComposeInternal` with `origCaller` read from the
callback's calldata. Inside that compose run the composer will pull funds / act on positions
**on behalf of `origCaller`** using the approvals users granted the composer. The *only* thing
stopping an attacker from calling the callback directly with `origCaller = victim` is the
`caller()` validation. Therefore:

> Every address the callback compares `caller()` against is fully trusted. If any one of them
> is attacker-controlled, or is a proxy whose admin turns malicious, an attacker can forge
> `origCaller` and drain every user who has an active approval/delegation to the composer.

Nothing in the callback path is taken from calldata for the trust decision — the comparands are
all compile-time `address private constant`s, so they are baked into the deployed bytecode and
cannot be changed without redeploying. That is the first and most important property: **trust
set is immutable per deployment.**

## The two callbacks on Hemi

### `AaveV3Callback.sol` — `executeOperation(...)`

Trusted comparands (selected by a `poolId` byte the composer itself embedded):

| poolId | constant | address | protocol |
|--------|----------|---------|----------|
| 20 | `ZEROLEND` | `0xdB7e029394a7cdbE27aBdAAf4D15e78baC34d6E8` | ZeroLend (Aave V3 fork) |
| 83 | `LENDOS` | `0xaA397b29510a7219A0f3f7cE3eb53A09bc2A924c` | Lendos (Aave V3 fork) |
| 91 | `LAYERBANK_V3` | `0xfeAce246DC83Ba5E4E95A67b1357D6Fd7C3C088f` | LayerBank V3 (Aave V3 fork) |

Two independent checks must both pass ([AaveV3Callback.sol:64](AaveV3Callback.sol#L64) and
[:73](AaveV3Callback.sol#L73)):

1. `caller() == pool` — the callback came from one of the three trusted pools.
2. `initiator == address(this)` — the flash loan was *self-initiated* by the composer.

**Assessment.** Check (2) is what neutralises the most realistic attack: an attacker calling the
*real* pool's `flashLoanSimple` with the composer as receiver and a forged `origCaller` in
`params`. A genuine Aave V3 pool sets `initiator` to the actual `flashLoanSimple` caller (the
attacker), so check (2) fails and the call reverts. Check (2) is only trustworthy if the pool
**honestly reports `initiator`** — i.e. it is a faithful Aave V3 implementation. So the trust in
each address is really trust that the address is:

- the canonical pool for that protocol on Hemi (no typo, no look-alike), **and**
- a faithful Aave-V3 `Pool` that reports `initiator` correctly, **and**
- governed safely. Aave V3 `Pool` is an **upgradeable proxy**; its admin/`PoolAddressesProvider`
  could in principle swap the implementation for one that lies about `initiator` or calls the
  callback with arbitrary params. Trust therefore extends to each fork's proxy admin / governance.
  This is the residual trust assumption to track for ZeroLend, Lendos and LayerBank.

Verification to perform before/at deployment (cannot be done from source alone):
- [ ] Each address is the official `Pool` (Aave `PoolAddressesProvider.getPool()`) for that fork on Hemi.
- [ ] Each is the proxy users actually interact with (so `caller()` matches in production).
- [ ] Record who controls each proxy admin; treat that key as part of the composer's trust base.

### `MorphoCallback.sol` — `onMorphoFlashLoan` / `onMorphoSupply` / `onMorphoRepay` / `onMorphoSupplyCollateral`

Trusted comparand (only `poolId == 0` is accepted):

| poolId | constant | address | protocol |
|--------|----------|---------|----------|
| 0 | `MORPHO_BLUE` | `0xa4Ca2c2e25b97DA19879201bA49422bc6f181f42` | Morpho Blue singleton |

Single check ([MorphoCallback.sol:68](MorphoCallback.sol#L68)): `caller() == MORPHO_BLUE`.

**Assessment.** There is no `initiator` parameter here, and none is needed: Morpho Blue's
flash-loan/supply/repay callbacks fire **only to the address that called the originating Morpho
function**. So the *only* way `onMorpho*` runs with `caller() == MORPHO_BLUE` is if the composer
itself called Morpho — which means the `origCaller` prefix in `params` was attached by the
composer in `morphoFlashLoan` ([../../../../flashLoan/Morpho.sol:54](../../../../flashLoan/Morpho.sol#L54)),
not by an attacker. This single check is therefore sufficient **provided the address is the real
Morpho Blue**. Morpho Blue is **immutable / non-upgradeable** by design, so unlike the Aave forks
there is no admin to trust — the trust collapses to "this is the canonical Morpho Blue address."

Note the callback also allows `onMorphoSupply`/`onMorphoRepay`/`onMorphoSupplyCollateral`, which
Morpho invokes during ordinary supply/repay (not just flash loans). Same guarantee applies:
Morpho only calls these back to the account that initiated the supply/repay (the composer).

Verification:
- [ ] `0xa4Ca…1f42` is the canonical Morpho Blue singleton on Hemi (compare against Morpho's official deployment registry).

## Generalisable trust criteria (apply to every chain's callbacks)

For each `caller()` comparand in any callback, confirm:

1. **Compile-time constant** — never a calldata value. (Verified true repo-wide; the comparand is
   always an `address private constant`.)
2. **Canonical address** — matches the protocol's official deployment for that chain; no typo or
   look-alike. This is the main per-chain review item and must be checked off-chain.
3. **Immutability / governance** —
   - Morpho Blue, Uniswap V4 PoolManager, Balancer V3 Vault: immutable singletons → trust is just "right address".
   - Aave V2/V3 (and forks: ZeroLend, Avalon, LayerBank, Granary, Radiant, Kinza, Spark, …) and
     Moolah/Lista: **upgradeable proxies** → trust additionally includes each proxy's admin/governance.
4. **Honest-`initiator` dependency** — Aave V2/V3 callbacks lean on `initiator == address(this)`,
   which is only as honest as the pool implementation. Faithful Aave forks are fine; exotic forks
   should be reviewed for a correct `initiator` semantic.
5. **Self-initiation semantics for no-initiator callbacks** — Morpho / Moolah / Uni V4 / Balancer V3
   rely on the singleton calling back only the initiator. Verify the integrated singleton actually
   has that property (all canonical ones do).

A full cross-chain inventory of every trusted constant can be regenerated with:

```
grep -rE "address (private|internal) constant [A-Z0-9_]+ = 0x" \
  contracts/1delta/composer/chains/*/flashLoan/callbacks \
  contracts/1delta/composer/chains/*/flashSwap/callbacks
```

## Bottom line for Hemi

Both callbacks are structurally safe: the trust set is immutable per deployment, Aave is
double-guarded (`caller()` whitelist + self-initiation), and Morpho relies on an immutable
singleton with callback-to-initiator semantics. The open items are **off-chain verifications**
(addresses are canonical; Aave-fork proxy admins are accounted for in the trust base), not code
changes.
