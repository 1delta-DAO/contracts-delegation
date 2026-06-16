# Callback Trust Assessment — etherlink

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
protocol's canonical deployment on etherlink, and for upgradeable pools record who controls the
proxy admin.

## `MorphoCallback.sol` — Morpho Blue

| constant | address |
|----------|---------|
| `MORPHO_BLUE` | `0xbCE7364E63C3B13C73E9977a83c9704E2aCa876e` |

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
