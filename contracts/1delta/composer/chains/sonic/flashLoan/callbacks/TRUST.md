# Callback Trust Assessment — sonic

Per-callback assessment of **which addresses this chain's callbacks trust** for `caller()`
validation, and why that trust is safe. Auto-generated from the callback sources in this
directory; see `chains/hemi/flashLoan/callbacks/TRUST.md` for the fully-annotated worked example
and the generalisable criteria.

## Why a wrong trusted address is catastrophic

A flash-loan / unlock callback re-enters `_deltaComposeInternal` with `origCaller` read from the
callback calldata, then acts **on behalf of `origCaller`** using the approvals users granted the
composer. The only thing preventing an attacker from calling the callback directly with
`origCaller = victim` is the `caller()` check. So every comparand below is fully trusted: if any
one is attacker-controlled — or is an upgradeable proxy whose admin turns malicious — an attacker
can forge `origCaller` and drain every user with an active approval/delegation to the composer.

Every comparand is a compile-time `address private constant` (never calldata), so the trust set
is **immutable per deployment**. The open review items are off-chain: confirm each address is the
protocol's canonical deployment on sonic, and for upgradeable pools record who controls the
proxy admin.

## `AaveV2Callback.sol` — Aave V2

| constant | address |
|----------|---------|
| `MAGSIN` | `0x73B635843352aF89278bDe2213866C457C94b271` |

**Defense:** `caller() ∈ {{trusted pools}}` **and** `initiator == address(this)` (self-initiation). The initiator check defeats an attacker who triggers a *real* pool's flash loan into the composer with a forged `origCaller` — a faithful Aave pool reports the attacker as `initiator`, so the call reverts. Trust therefore requires each address to be a faithful Aave implementation that reports `initiator` honestly.
**Mutability:** Aave-style `Pool`s are **upgradeable proxies** — trust extends to each fork's proxy admin / governance.

## `AaveV3Callback.sol` — Aave V3

| poolId | constant | address |
|--------|----------|---------|
| 0 | `AAVE_V3` | `0x5362dBb1e601abF3a4c14c22ffEdA64042E5eAA3` |
| 50 | `AVALON` | `0x974E2B16ddbF0ae6F78b4534353c2871213f2Dc9` |
| 55 | `AVALON_USDA` | `0xD33Ee43551167cdd15Ef9CF87ceecC0fF69Cc922` |
| 61 | `AVALON_BEETS` | `0x6CCE1BC3fe54C9B1915e5f01ee076E4c4C3Cdd19` |

**Defense:** `caller() ∈ {{trusted pools}}` **and** `initiator == address(this)` (self-initiation). The initiator check defeats an attacker who triggers a *real* pool's flash loan into the composer with a forged `origCaller` — a faithful Aave pool reports the attacker as `initiator`, so the call reverts. Trust therefore requires each address to be a faithful Aave implementation that reports `initiator` honestly.
**Mutability:** Aave-style `Pool`s are **upgradeable proxies** — trust extends to each fork's proxy admin / governance.

## `BalancerV3Callback.sol` — Balancer V3

| constant | address |
|----------|---------|
| `BALANCER_V3` | `0xbA1333333333a1BA1108E8412f11850A5C319bA9` |

**Defense:** `caller() == BALANCER_V3` only, plus a custom callback selector. The Vault releases its lock only to the account that called `unlock` (the composer), so `origCaller` was attached by the composer.
**Mutability:** the Balancer V3 Vault is an **immutable singleton** — trust collapses to the canonical address.

## `MorphoCallback.sol` — Morpho Blue

| constant | address |
|----------|---------|
| `MORPHO_BLUE` | `0xd6c916eB7542D0Ad3f18AEd0FCBD50C582cfa95f` |

**Defense:** `caller() == MORPHO_BLUE` only. Sufficient because Morpho calls these callbacks back **only to the account that initiated** the flash/supply/repay (the composer), so the `origCaller` prefix was attached by the composer itself.
**Mutability:** Morpho Blue is **immutable / non-upgradeable** — no admin to trust; the trust collapses to "this is the canonical Morpho Blue address."

## Off-chain verification checklist

- [ ] Each address above is the protocol's **canonical** deployment on this chain (no typo / look-alike).
- [ ] For upgradeable pools (Aave forks, Moolah): record the proxy admin / governance controlling each — it is part of the composer's trust base.
- [ ] For Aave-type callbacks: confirm each fork reports `initiator` with faithful Aave semantics.

Regenerate the cross-chain inventory of all trusted constants with:

```
grep -rE "address (private|internal) constant [A-Z0-9_]+ = 0x" \
  contracts/1delta/composer/chains/*/flashLoan/callbacks \
  contracts/1delta/composer/chains/*/flashSwap/callbacks
```
