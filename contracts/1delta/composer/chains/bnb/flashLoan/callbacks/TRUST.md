# Callback Trust Assessment — bnb

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
protocol's canonical deployment on bnb, and for upgradeable pools record who controls the
proxy admin.

## `AaveV2Callback.sol` — Aave V2

| poolId | constant | address |
|--------|----------|---------|
| 7 | `GRANARY` | `0x7171054f8d148Fe1097948923C91A6596fC29032` |
| 16 | `VALAS` | `0xE29A55A6AEFf5C8B1beedE5bCF2F0Cb3AF8F91f5` |
| 20 | `RADIANT_V2` | `0xCcf31D54C3A94f67b8cEFF8DD771DE5846dA032c` |

**Defense:** `caller() ∈ {{trusted pools}}` **and** `initiator == address(this)` (self-initiation). The initiator check defeats an attacker who triggers a *real* pool's flash loan into the composer with a forged `origCaller` — a faithful Aave pool reports the attacker as `initiator`, so the call reverts. Trust therefore requires each address to be a faithful Aave implementation that reports `initiator` honestly.
**Mutability:** Aave-style `Pool`s are **upgradeable proxies** — trust extends to each fork's proxy admin / governance.

## `AaveV3Callback.sol` — Aave V3

| poolId | constant | address |
|--------|----------|---------|
| 0 | `AAVE_V3` | `0x6807dc923806fE8Fd134338EABCA509979a7e0cB` |
| 51 | `AVALON_SOLVBTC` | `0xf9278C7c4AEfAC4dDfd0D496f7a1C39cA6BCA6d4` |
| 53 | `AVALON_PUMPBTC` | `0xeCaC6332e2De19e8c8e6Cd905cb134E980F18cC4` |
| 64 | `AVALON_STBTC` | `0x05C194eE95370ED803B1526f26EFd98C79078ab5` |
| 65 | `AVALON_WBTC` | `0xF8718Fc27eF04633B7EB372F778348dE02642207` |
| 66 | `AVALON_LBTC` | `0x390166389f5D30281B9bDE086805eb3c9A10F46F` |
| 67 | `AVALON_XAUM` | `0x4B801fb6f0830D070f40aff9ADFC8f6939Cc1F8D` |
| 68 | `AVALON_LISTA` | `0x54925C6dDeB73A962B3C3A21B10732eD5548e43a` |
| 69 | `AVALON_USDX` | `0x77fF9B0cdbb6039b9D42d92d7289110E6CCD3890` |
| 70 | `AVALON_UNIBTC` | `0x795Ae4Bd3B63aA8657a7CC2b3e45Fb0F7c9ED9Cc` |
| 82 | `KINZA` | `0xcB0620b181140e57D1C0D8b724cde623cA963c8C` |

**Defense:** `caller() ∈ {{trusted pools}}` **and** `initiator == address(this)` (self-initiation). The initiator check defeats an attacker who triggers a *real* pool's flash loan into the composer with a forged `origCaller` — a faithful Aave pool reports the attacker as `initiator`, so the call reverts. Trust therefore requires each address to be a faithful Aave implementation that reports `initiator` honestly.
**Mutability:** Aave-style `Pool`s are **upgradeable proxies** — trust extends to each fork's proxy admin / governance.

## `MoolahCallback.sol` — Moolah / Lista

| constant | address |
|----------|---------|
| `LISTA_DAO` | `0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C` |

**Defense:** `caller() == LISTA_DAO` only. Sufficient because Moolah calls these callbacks back only to the initiating account (the composer), so `origCaller` was attached by the composer.
**Mutability:** Moolah (Lista DAO) is an **upgradeable proxy** — trust extends to its proxy admin / governance.

## `MorphoCallback.sol` — Morpho Blue

| constant | address |
|----------|---------|
| `MORPHO_BLUE` | `0x01b0Bd309AA75547f7a37Ad7B1219A898E67a83a` |

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
