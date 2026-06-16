# Callback Trust Assessment — polygon

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
protocol's canonical deployment on polygon, and for upgradeable pools record who controls the
proxy admin.

## `AaveV2Callback.sol` — Aave V2

| constant | address |
|----------|---------|
| `AAVE_V2` | `0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf` |

**Defense:** `caller() ∈ {{trusted pools}}` **and** `initiator == address(this)` (self-initiation). The initiator check defeats an attacker who triggers a *real* pool's flash loan into the composer with a forged `origCaller` — a faithful Aave pool reports the attacker as `initiator`, so the call reverts. Trust therefore requires each address to be a faithful Aave implementation that reports `initiator` honestly.
**Mutability:** Aave-style `Pool`s are **upgradeable proxies** — trust extends to each fork's proxy admin / governance.

## `AaveV3Callback.sol` — Aave V3

| constant | address |
|----------|---------|
| `AAVE_V3` | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` |

**Defense:** `caller() ∈ {{trusted pools}}` **and** `initiator == address(this)` (self-initiation). The initiator check defeats an attacker who triggers a *real* pool's flash loan into the composer with a forged `origCaller` — a faithful Aave pool reports the attacker as `initiator`, so the call reverts. Trust therefore requires each address to be a faithful Aave implementation that reports `initiator` honestly.
**Mutability:** Aave-style `Pool`s are **upgradeable proxies** — trust extends to each fork's proxy admin / governance.

## `MorphoCallback.sol` — Morpho Blue

| constant | address |
|----------|---------|
| `MORPHO_BLUE` | `0x1bF0c2541F820E775182832f06c0B7Fc27A25f67` |

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
