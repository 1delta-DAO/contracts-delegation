# Callback-Source Trust — Freeze-Forever Decision Record

The composers are deployed as **plain immutable bytecode** (no owner, no proxy, no upgrade path,
no privileged setter — verified). Once ownership of the peripheral tooling is renounced, every
hardcoded trusted address and every CREATE2 fork constant in the callbacks is **frozen forever**.
This document records, per callback source, why it is safe to freeze: it must be **immutable by
construction**, **strongly governed**, or a **documented manual acceptance**.

Companion doc: [ACCEPTED_LENDERS.md](./ACCEPTED_LENDERS.md) (lender-by-lender detail + the
flash-loan blacklist policy). Audit date: 2026-07. Governance/immutability facts marked *(verified)*
were read on-chain (proxy-slot / owner / timelock / CREATE2 re-derivation).

## What "renounce owner" touches

Nothing on the composers. The only `Ownable` in scope is `contracts/validator/AddressWhitelistManager.sol`,
which backs the **off-chain** `ComposerValidator` and is referenced nowhere in the on-chain execution
path. Renouncing it freezes the off-chain validator's whitelist and cannot change, pause, or brick any
deployed composer. The composers hold no funds at rest, so the absence of a pause/rescue is safe; the
permissionless `_approve` (permanent max approval) is inert with zero balance between transactions.

## 1. Singleton callback sources

| Source | Chains | Class | Basis (verified) |
|---|---|---|---|
| Morpho Blue | 31 | **IMMUTABLE** | Non-proxy; owner may only set IRM/LLTV/fee, cannot upgrade or redirect the callback. All 31 addresses canonical |
| Uniswap V4 PoolManager | 16 | **IMMUTABLE** | Non-proxy; owner = protocol-fee only. Canonical per Uniswap deployments doc |
| Balancer V3 Vault | 9 | **IMMUTABLE** | Non-proxy; extension/admin are construction-set immutables. Governance can *pause* (availability), not upgrade/redirect |
| Morpho Midnight | base | **IMMUTABLE** | Non-proxy, no upgrade/pause. Callback additionally hardened by `initiator == address(this)` |
| **Lista / Moolah** | eth, bnb | **MANUAL ACCEPT** | ⚠️ *Upgradeable* ERC-1967 proxy, 24h TimelockController → Lista multisig. **Accepted**: trusted ~$1B lender; upgrade gated by a 24h timelock. This is the one mutable singleton — accepted knowingly |

### Morpho Blue coverage gap (composer deployments missing a Morpho callback)

Morpho Blue is integrated on **31** chains (all IMMUTABLE, canonical). Of the 20 composer chains
without a Morpho callback, **6 have an official canonical Morpho Blue deployment** (verified on-chain
— identical 31,166-byte Morpho runtime) and are **missing integrations worth adding** (Morpho Blue is
immutable, so freeze-safe):

| Chain | Chain ID | Morpho Blue singleton |
|---|---|---|
| avalanche | 43114 | `0x895383274303AA19fe978AFB4Ac55C7f094f982C` |
| gnosis | 100 | `0xB74D4dd451E250bC325AFF0556D717e4E2351c66` |
| megaeth | 4326 | `0x18120312A7cf44DcfEc6dCe5632a431579ED9100` |
| morph | 2818 | `0xAd10d07901Dc3195c3cb5e78E061F4EA8D9B4905` |
| plasma | 9745 | `0x2fF74A46536f5c67ef5A42FD5B4e2Ed8A2cee249` |
| xdc | 50 | `0xEa49B0fE898aF913A3826F9f462eE2cDcb854fD9` |

The other 14 (blast, bob, core, fantom-opera, goat, manta-pacific, mantle, metis, moonbeam,
pulsechain, taiko, telos, x-layer, zksync) have **no** Morpho deployment. Notes: fantom-opera → the
chain rebranded to **Sonic** (chain 146), already integrated; **zkSync Era** has no Morpho (Morpho's
only zkStack deployment is **Abstract**, already integrated).

## 2. Aave V2/V3 callback sources

Weak/EOA-governed forks were blacklisted in earlier rounds (see ACCEPTED_LENDERS.md §5). Remaining
accepted set:

- **Vanilla Aave (official Aave DAO):** `AAVE_V3` (canonical, ~20 chains), `AAVE_V3_PRIME`,
  `AAVE_V3_ETHER_FI`, `AAVE_V3_HORIZON`, `AAVE_V3_POOL` (zkSync), `AAVE_V2` (eth/polygon/avax).
- **Spark:** `SPARK` (eth, gnosis) — Sky/Maker licensed fork, strong governance.
- **Other forks (STRONG_GOV):** `HYPERLEND` (HyperEVM), `YEI`-main (Sei, 24h timelock + 4/10).
- **MANUAL ACCEPT (dominant-lender):** `PHIAT` (PulseChain — kept on Pulse, excluded on Ethereum).

After the removals below, the ONLY non-vanilla / non-Spark Aave forks remaining are **HYPERLEND**,
**YEI**, and **PHIAT** (the Pulse exception).

**Removed:**
- `COLEND`, `COLEND_LSTBTC` (Core), `FATHOM` (XDC) — flash loans frozen/disabled at the protocol
  (below the strong-gov bar anyway). Deletes the Core and XDC `AaveV3Callback.sol`.
- `KINZA` (BNB), `XLEND` (Base/Optimism) — removed for **coverage, not governance**: both are safely
  governed (Kinza 4h timelock + 2/3; XLend 24h + 3/6), but their assets are already supported by
  Aave V3 on the same chains, so they add no unique flash-loan coverage. BNB/Base/Optimism keep
  vanilla Aave V3.

All in `scripts/_create/lenderExclusions.ts` (+ SDK `flashLoanExclusions.ts`).

## 3. Uniswap-V3-style forks (flash callbacks)

The callback authenticates the caller by re-deriving `CREATE2(deployer, salt, INIT_CODE_HASH)`. The
frozen `INIT_CODE_HASH` is a **cryptographic commitment to the exact pool creation bytecode** — only a
contract whose creation code hashes to that value can pass `caller() == pool`, and a genuine
UniV3/Algebra pool invokes the swap/flash callback **only on `msg.sender`** with the initiator's data.
So a fork is immutable-by-construction iff that hash pins a standard, non-proxy, admin-less pool.

53 forks collapse to 28 distinct hashes. **All confirmed IMMUTABLE** (on-chain CREATE2 re-derivation +
byte-identical codesize within each hash group + `msg.sender`-only callback), **except the three
removed below**:

- Canonical Uniswap-V3 hash `0xe34f199b` (UNISWAP_V3, SUSHISWAP_V3, AlienBase, BaseX, Corex, Dackie,
  DTX, Kinetix, Maia, Sonex, TaikoSwap) — derivation hits the real mainnet WETH/USDC pool.
- Pancake V3 (PancakeSwap V3, Panko); Camelot/Hercules; Solidly V3; and every Algebra fork
  (Thena, Lynex, Fenix, Blade, StellaSwap V3/V4, QuickSwap, Swapsicle, Bulla, Horizon, Kim, Molten,
  Silver_Swap, SwapX, SwapBased, Synthswap, Atlas, Holiverse, Mor_Fi, Wasabee, Ubeswap, Litx,
  Skullswap, Zyberswap, Henjin, Scribe) — Algebra pools hardcode `IAlgebra*Callback(msg.sender)`;
  Integral plugins are fixed-signature hooks, not an arbitrary-call vector.
- Kodiak, Hyperswap, Kyo, DragonSwap, Sailor, Wagmi, IceCream, Retro — verified standard UniV3 forks
  (several by bytecode disassembly of the callback region). Both non-canonical Sushi hashes
  (Blast/Katana) are benign chain-specific recompiles.

**Removed in this round** (blacklisted in `scripts/_create/dex/blacklists.ts`):

| Fork | Chain | Reason |
|---|---|---|
| `METHLAB` | Mantle | Removed **conservatively**. Deep review (verified source + CREATE2 + disasm): pool is callback-safe — the only mod is a whitelist gate in `mint()`; `swap()`/`flash()` are stock UniV3, `msg.sender`-only, ChainSecurity-audited. Kept out of the frozen set as a small/semi-anon DEX, **not** a security necessity |
| `CRUST` | Mantle | Pool is bytecode-verified callback-safe, but the **DEX is abandoned** (~$0 TVL, site redirects away) — removed on viability grounds |
| `UNAGI_V3` | Taiko | **DODO white-label** — DODO deployments were removed entirely; also abandoned (~$0 TVL). Removed |

**ICECREAM_V3 (Core) — misconfiguration FIXED:** the constant embedded the **factory**
(`0xa8a3AAD4…`) but IceCream is Pancake-style with a **separate PoolDeployer**, so `CREATE2(factory,…)`
matched no real pool (the flash path was a fail-closed no-op — harmless, not exploitable). Repointed to
the real PoolDeployer **`0xF9f83b79…`** — confirmed on-chain (`factory.poolDeployer()` returns it;
`CREATE2(deployer, salt, hash)` reproduces live pools; factory does not). Applied as a codegen override
in `scripts/_create/uniV3FlashForks.ts` (`FF_FACTORY_OVERRIDES`) and fixed at the registry source; the
regenerated `ICECREAM_V3_FF_FACTORY` now embeds `0xf9f83b79…` and pools are verified immutable.

*Viability note (freeze-safe, not removed):* Retro and Solidly V3 are immutable pools but near-dead
(low TVL) — they can never become a drain vector; drop later for hygiene if desired.

### UniV3-style fork source inventory (verified this iteration)

Grouped by frozen pool init-code-hash (the CREATE2 commitment). Same hash ⇒ byte-identical pool
bytecode ⇒ one verdict covers the group. The per-chain factory/PoolDeployer address lives in each
chain's `UniV3Callback.sol` (`*_FF_FACTORY`). All KEPT forks verified **IMMUTABLE** — genuine
non-proxy, admin-less UniV3/Algebra/Pancake pools whose swap/flash callback fires only on `msg.sender`.

| Init-code-hash | Pool impl | Forks (chains) | Verdict |
|---|---|---|---|
| `0xe34f199b…` | **Canonical UniswapV3Pool** (= Uniswap `POOL_INIT_CODE_HASH`; derivation hits real ETH WETH/USDC pool) | UNISWAP_V3, SUSHISWAP_V3, ALIENBASE_V3, BASEX_V3, COREX, DACKIESWAP_V3, DTX, KINETIX_V3, MAIA_V3, SONEX_V3, TAIKOSWAP_V3 (~30 chains) | IMMUTABLE (very high) |
| `0x6ce8eb47…` | PancakeV3Pool (deployer = PancakeV3 PoolDeployer) | PANCAKESWAP_V3, PANKO (taiko) | IMMUTABLE (very high) |
| `0xb3fc09be…` | Algebra Integral | QUICKSWAP_V3 (soneium), ATLAS (hemi), HOLIVERSE (polygon), MOR_FI (morph), STELLASWAP_V4 (moonbeam), WASABEE (berachain) | IMMUTABLE (high) |
| `0x6ec6c9c8…` | Algebra V1 (QuickSwap-Polygon reference) | QUICKSWAP_V3 (polygon), LITX (bnb), SKULLSWAP (fantom), UBESWAP (celo), ZYBERSWAP (arbitrum) | IMMUTABLE (very high) |
| `0xf96d2474…` | Algebra Integral | BULLA (berachain), HORIZON (linea), KIM (mode), MOLTEN (core), SILVER_SWAP (fantom), SWAPSICLE (taiko), SWAPX (sonic) | IMMUTABLE (high) |
| `0xbce37a54…` | Algebra | SWAP_BASED (base), SYNTHSWAP (base), ZYBERSWAP (op) | IMMUTABLE (high) |
| `0x6c1bebd3…` | Camelot Algebra V1.9 | CAMELOT (arbitrum), HERCULES (metis) | IMMUTABLE (very high) |
| `0x4b9e4a80…` | Algebra Integral | HENJIN (taiko), SCRIBE (scroll) | IMMUTABLE (high) |
| `0xe9b68c5f…` | SolidlyV3 pool | SOLIDLY_V3 (eth, base, sonic) | IMMUTABLE (high) |
| `0xd61302e7…` | Algebra V1.0 | THENA (bnb) | IMMUTABLE (high) |
| `0x817e0795…` | UniV3 fork | RETRO (polygon) — *near-dead* | IMMUTABLE (high) |
| `0xc65e01e6…` | Algebra V1.9 | LYNEX (linea) | IMMUTABLE (high) |
| `0xf45e886a…` | Algebra Integral | FENIX (blast) | IMMUTABLE (high) |
| `0xa9df2657…` | Algebra Integral | BLADE (blast) | IMMUTABLE (high) |
| `0x424896f6…` | Algebra V1.0 | STELLASWAP_V3 (moonbeam) | IMMUTABLE (high) |
| `0xf54c8516…` | UniV3 fork | KYO_V3 (soneium) | IMMUTABLE (med-high) |
| `0x7e42a0cb…` | UniV3 fork *(bytecode-verified)* | SAILOR (sei) | IMMUTABLE (high) |
| `0xe3572921…` | UniV3 fork *(bytecode-verified)* | HYPERSWAP_V3 (hyperevm) | IMMUTABLE (high) |
| `0x2b1d8d8c…` | PancakeV3 fork *(bytecode-verified)* | DRAGONSWAP_V3 (kaia) | IMMUTABLE (high) |
| `0x30146866…` | UniV3 fork *(bytecode-verified, 3 chains)* | WAGMI (metis, sonic, arbitrum) | IMMUTABLE (high) |
| `0xd8e2091b…` | UniV3 fork | KODIAK_V3 (berachain) | IMMUTABLE (high) |
| `0x177d5fbf…` | Algebra Integral | SWAPSICLE (telos, mantle) | IMMUTABLE (med) |
| `0x8e13daee…` | UniV3 (Blast recompile) | SUSHISWAP_V3 (blast) | IMMUTABLE (high) |
| `0xe040f12c…` | UniV3 (Katana recompile) | SUSHISWAP_V3 (katana) | IMMUTABLE (med-high) |
| `0x0c6b99bf…` | PancakeV3 fork | ICECREAM_V3 (core) | pool IMMUTABLE — **constant misconfigured, being fixed** |
| `0xacd26fbb…` | UniV3 (mint-whitelist mod) | ~~METHLAB (mantle)~~ | **REMOVED** (conservative; pool callback-safe) |
| `0x55664e1b…` | UniV3 fork | ~~CRUST (mantle)~~ | **REMOVED** (abandoned) |
| `0x5ccd5621…` | Algebra (DODO white-label) | ~~UNAGI_V3 (taiko)~~ | **REMOVED** (DODO, removed entirely) |

## 4. Non-source-validation callbacks (informational)

- `swapX2YCallback` / `swapY2XCallback` (`quoter/dex/V3TypeQuoter.sol`) are **quoter-only** (`external
  pure`, they revert to extract a quote) — not an execution-path trusted-source surface.
- The composer implements **no** `uniswapV3SwapCallback` and **no** Midnight `onRepay`/`onBuy`/`onSell`
  receiver — it forces those callback fields to zero and is never a passive callback target. Only
  `onFlashLoan` (Midnight) and the flash/unlock callbacks above are implemented, all validated.

## Pre-renounce checklist — status

- [x] Composers verified immutable (no owner/admin/upgrade). "Renounce owner" only affects off-chain validator.
- [x] Singletons: Morpho Blue / UniV4 / Balancer V3 / Midnight IMMUTABLE; Lista/Moolah accepted (trusted ~$1B lender, 24h timelock).
- [x] Aave sources: strong-gov or documented accept; COLEND/COLEND_LSTBTC/FATHOM removed (frozen flash loans).
- [x] UniV3 forks: all confirmed immutable except METHLAB/CRUST/UNAGI_V3 — **removed**.
- [x] Regenerated callbacks + tests; `forge build` green; cross-repo lender-exclusion parity holds; SDK typechecks.
