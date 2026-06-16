# Callback Trust Assessment — gnosis

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
protocol's canonical deployment on gnosis, and for upgradeable pools record who controls the
proxy admin.

## `AaveV2Callback.sol` — Aave V2

| constant | address |
|----------|---------|
| `AGAVE` | `0x5E15d5E33d318dCEd84Bfe3F4EACe07909bE6d9c` |

**Defense:** `caller() ∈ {{trusted pools}}` **and** `initiator == address(this)` (self-initiation). The initiator check defeats an attacker who triggers a *real* pool's flash loan into the composer with a forged `origCaller` — a faithful Aave pool reports the attacker as `initiator`, so the call reverts. Trust therefore requires each address to be a faithful Aave implementation that reports `initiator` honestly.
**Mutability:** Aave-style `Pool`s are **upgradeable proxies** — trust extends to each fork's proxy admin / governance.

## `AaveV3Callback.sol` — Aave V3

| poolId | constant | address |
|--------|----------|---------|
| 0 | `AAVE_V3` | `0xb50201558B00496A145fE76f7424749556E326D8` |
| 10 | `SPARK` | `0x2Dae5307c5E3FD1CF5A72Cb6F698f915860607e0` |
| 90 | `RMM` | `0xFb9b496519fCa8473fba1af0850B6B8F476BFdB3` |

**Defense:** `caller() ∈ {{trusted pools}}` **and** `initiator == address(this)` (self-initiation). The initiator check defeats an attacker who triggers a *real* pool's flash loan into the composer with a forged `origCaller` — a faithful Aave pool reports the attacker as `initiator`, so the call reverts. Trust therefore requires each address to be a faithful Aave implementation that reports `initiator` honestly.
**Mutability:** Aave-style `Pool`s are **upgradeable proxies** — trust extends to each fork's proxy admin / governance.

## `BalancerV3Callback.sol` — Balancer V3

| constant | address |
|----------|---------|
| `BALANCER_V3` | `0xbA1333333333a1BA1108E8412f11850A5C319bA9` |

**Defense:** `caller() == BALANCER_V3` only, plus a custom callback selector. The Vault releases its lock only to the account that called `unlock` (the composer), so `origCaller` was attached by the composer.
**Mutability:** the Balancer V3 Vault is an **immutable singleton** — trust collapses to the canonical address.

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
