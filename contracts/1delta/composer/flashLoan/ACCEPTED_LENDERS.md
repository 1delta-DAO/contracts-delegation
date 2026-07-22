# Accepted Lenders & Flash-Loan Providers — Trust Map

This document maps every lending protocol / flash-loan provider the composer **hardcode-trusts**
as a flash-loan callback caller, and the reason each is accepted. The accept/reject decision is
enforced in code by [`scripts/_create/lenderExclusions.ts`](../../../../scripts/_create/lenderExclusions.ts),
which the callback code-generator reads.

## Why this matters (the trust vector)

A flash-loan callback validates `caller() == <hardcoded pool>`. During the loan the composer
approves that pool to pull back principal + premium. If the trusted pool is **upgradeable by a
single EOA** (or a trivially-compromised key), a malicious implementation could abuse that
approval to drain funds in-flight. Therefore the operative bar for hardcode-trust is:

> **The pool implementation must NOT be upgradeable by a single EOA.**
> Prefer: original Aave DAO, or a fork with a real multisig (ideally + timelock) / DAO.

Governance facts below marked **(on-chain verified)** were read directly from each chain's RPC
(provider `owner()` / `getACLAdmin()`, Safe `getThreshold`/`getOwners`, TimelockController
`getMinDelay`) during the July 2026 fork-trust audit.

---

## 1. Official Aave deployments — ACCEPTED (original)

Governed by Aave Governance (DAO + cross-chain executor + timelock). Highest trust.

| Lender | Chains | Notes |
|---|---|---|
| `AAVE_V3` | arbitrum, avalanche, base, bnb, celo, ethereum, gnosis, ink, linea, mantle, megaeth, metis, monad, op, plasma, polygon, scroll, soneium, sonic, x-layer | Canonical Aave V3 (Pool `0x794a…14aD` on most; per-chain official pools elsewhere) |
| `AAVE_V3_POOL` | zksync | Official Aave V3 zkSync Era (verified vs bgd-labs address-book) |
| `AAVE_V3_PRIME` | ethereum | Official Aave DAO instance (ex-"Lido", gov proposal 133) |
| `AAVE_V3_ETHER_FI` | ethereum | Official Aave DAO instance (gov proposal ~157) |
| `AAVE_V3_HORIZON` | ethereum | Official but **Aave-Labs-operated & permissioned** (RWA/institutional); less trust-minimized than core |
| `AAVE_V2` | ethereum, polygon, avalanche | Canonical Aave V2 (matches bgd-labs address-book) |

## 2. Aave forks — ACCEPTED (strong / adequate governance)

| Lender | Chains | Governance (on-chain verified) | Tier | Reason accepted |
|---|---|---|---|---|
| `SPARK` | ethereum, gnosis | Sky/MakerDAO SubDAO, timelock-gated, multi-audit, multi-B TVL | **Strong** | Reputable DAO (Sky), not single-EOA |
| `HYPERLEND` | hyperevm | Aave-recognized "friendly fork"; team multisig; Ackee/Cantina/Pashov audits; ~$540M | **Strong (fork)** | Well-audited, multisig-governed |
| `YEI` (main market only) | sei | **24h timelock + 4-of-10 Safe** | **Adequate** | Timelock + multisig. **YEI_SOLV market rejected** (no timelock) |

> Removed since the first cut (still governance-safe, but dropped): **`XLEND`** (base/op, 24h + 3/6)
> and **`KINZA`** (bnb, 4h + 2/3) — removed for **coverage** (assets already served by Aave V3 on
> those chains). **`FATHOM`** (xdc, 3/5 no-timelock) — removed with flash loans frozen at the protocol.
> After these, the only non-vanilla/non-Spark Aave forks are **HYPERLEND**, **YEI**, and the Pulse
> exception **PHIAT**.

## 3. Aave forks — ACCEPTED as EXCEPTIONS (below strong-gov bar; kept for chain coverage)

These do **not** meet the strong-governance bar but are the dominant lender on their chain.
**Governing rationale:** each holds such a large share of its chain's TVL that its failure is
effectively a **chain-level failure** — so hardcode-trusting it adds no meaningful marginal risk
beyond the chain risk already accepted by deploying there. They are kept knowingly on that basis.
(All are multisig/opaque-admin, not verified single-EOA, but none has an enforced upgrade timelock.)

| Lender | Chain | Governance (on-chain verified) | Why kept | Residual risk |
|---|---|---|---|---|
| `PHIAT` | pulsechain | Anon team (RH/PulseChain ecosystem), admin undisclosed; 2 audits (Solidity Finance, CertiK) | Main lender on PulseChain (most TVL) | Anon, opaque admin — highest-risk exception |
| `COLEND` (+ `COLEND_LSTBTC`) | core | **2-of-3 Gnosis Safe, no timelock, anonymous signers**; Halborn/CertiK/Verichains audits; ~$158M (~45% of Core TVL) | Dominant lender on Core (~45% of chain TVL) | Un-timelocked anon 2/3 multisig — accepted knowingly (see rationale) |

> **Decision (settled):** `COLEND` is kept despite the weak 2-of-3 / no-timelock / anon governance.
> Rationale: it is ~45% of all Core TVL, so a Colend compromise is effectively a **Core-chain-level
> failure** — hardcode-trusting it adds no meaningful marginal risk beyond the chain risk already
> accepted by deploying on Core. Same "dominant-lender" basis as Moola (Celo) and Phiat (PulseChain).

## 4. Non-Aave flash-loan providers — ACCEPTED (trustless by construction)

These are not "forks" and do not rely on a governance judgement — the callback trust is
structural (canonical immutable singleton, or a CREATE2-derived pool address).

| Provider | Chains | Trust basis |
|---|---|---|
| Morpho Blue (`MORPHO_BLUE`) | 31 | Canonical immutable singleton; callback only ever fires on `msg.sender` (self-initiation) |
| Moolah / Lista (`LISTA_DAO`) | ethereum, bnb | Morpho-Blue fork; canonical singleton, msg.sender-only callback |
| Morpho Midnight (`MIDNIGHT`) | base | Canonical instance; ERC-3156, `initiator == address(this)` enforced |
| Uniswap V3 / Algebra / Pancake | 42 | CREATE2 pool re-derivation (`keccak256(0xff ++ factory ++ salt ++ initHash)`); attacker cannot occupy a derived pool address |
| Uniswap V4 (`UNISWAP_V4`) | 16 | Canonical PoolManager singleton; unlock callback only fires on `msg.sender` |
| Balancer V3 (`BALANCER_V3`) | 9 | Canonical Vault singleton; unlock callback only fires on `msg.sender` |

## 5. REJECTED forks — blacklisted from codegen

Removed because they are neither original Aave nor strongly-governed (single-EOA upgradeable,
anon/opaque, unaudited, defunct, or previously exploited). Full list & per-fork reasons live in
[`scripts/_create/lenderExclusions.ts`](../../../../scripts/_create/lenderExclusions.ts).

| Rejected | Reason |
|---|---|
| `SAKE`, `SAKE_ASTAR` | Single EOA behind a cosmetic 10-min timelock (verified) |
| `VALAS`, `KLAYBANK`, `PHIAT`(eth only) | Anon / opaque admin |
| `NEREUS`, `AGAVE`, `MOOLA`, `POLTER`, `PAC`, `ZEROLEND` | Prior exploits / bad-debt / EOA-admin. `MOOLA` (Celo, 4/10 no-timelock, 2022 oracle exploit, near-dormant) removed to stay conservative — Celo keeps its Aave V3 flash source |
| `LORE`, `HYPURRFI`, `AURELIUS` | Winding down / sunsetting / abandoned |
| `HYPERYIELD`, `NEVERLAND`, `AQUALOAN`, `MERIDIAN`, `TAKOTAKO` | New/obscure, unverified governance, no reputable audit |
| `YEI_SOLV` | 2nd Yei market: multisig-only, no timelock (main market kept) |
| `GRANARY`, `IRONCLAD` | Byte Masons/Conclave multisig+timelock — below strong-gov bar (not single-EOA; reversible if desired) |
| `PRIME_FI` | EOA-governed on HyperEVM/XDC; on Base its assets are covered better elsewhere |
| plus: `BETTER_BANK*`, `LAYERBANK_V3`, `RADIANT_V2`, `SEISMIC`, `RMM`, `LENDOS`, `KLAP`, `RHOMBUS`, `MOLEND`, `HANA`, `MAGSIN`, `KONA_LEND`, `YLDR`, `LENDLE*`, `AVALON*` | EOA-governed / niche / defunct (pre-existing exclusions) |

## Scope note

This map governs the **on-chain flash-loan trusted set** (which pools the composer will call and
trust as callback callers). It does **not** control which lenders are offered for **lending** in the
UI — the composer's lending path is generic (the pool address is supplied in calldata), so gating
user-facing lending options is a separate change in the frontend registry (`@1delta/data-sdk`).
