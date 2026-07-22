/**
 * Lender exclusions for flash loan callbacks.
 *
 * `ALWAYS` lists lender entityNames dropped from every chain — used for protocols that are
 * niche everywhere and whose assets are covered by other (larger) flash loan providers on the
 * same chain. Each entry removed saves ~50-80 bytes from the generated callback's bytecode.
 *
 * `BY_CHAIN` lists per-chain-specific exclusions (keyed by Chain enum value, e.g. "1" = Ethereum).
 * Used to keep individual chain composers under the EIP-170 runtime limit (24,576 bytes) when the
 * always-excluded set alone isn't enough.
 */
export const FLASH_LOAN_LENDER_EXCLUSIONS = {
    ALWAYS: [
        // Very niche on every chain; their supported assets are served by AAVE_V3 / SPARK / etc.
        "YLDR",
        // Aave V2 fork, very low volume — seen on Base / Sonic where larger Aave V3 forks cover the same assets.
        "POLTER",
        // Taiko Aave V2 forks — low volume, narrow asset coverage.
        "TAKOTAKO",
        "TAKOTAKO_ETH",
        // Mantle — Aave V2 fork.
        "AURELIUS",
        // Mantle — Lendle main market + its 14 single-asset sub-markets.
        // Each pool covers a single asset that's already available through other (larger) markets on Mantle.
        "LENDLE",
        "LENDLE_CMETH",
        "LENDLE_PT_CMETH",
        "LENDLE_SUSDE",
        "LENDLE_SUSDE_USDT",
        "LENDLE_METH_WETH",
        "LENDLE_METH_USDE",
        "LENDLE_CMETH_WETH",
        "LENDLE_CMETH_USDE",
        "LENDLE_CMETH_WMNT",
        "LENDLE_FBTC_WETH",
        "LENDLE_FBTC_USDE",
        "LENDLE_FBTC_WMNT",
        "LENDLE_WMNT_WETH",
        "LENDLE_WMNT_USDE",

        // ZeroLend — project defunct, removed on every chain.
        "ZEROLEND",
        "ZEROLEND_STABLECOINS_RWA",
        "ZEROLEND_ETH_LRTS",
        "ZEROLEND_BTC_LRTS",
        "ZEROLEND_CROAK",
        "ZEROLEND_FOXY",

        // Avalon — all markets removed across the board (Aave forks, weak/EOA governance).
        "AVALON",
        "AVALON_SOLVBTC",
        "AVALON_SWELLBTC",
        "AVALON_PUMPBTC",
        "AVALON_UNIBTC",
        "AVALON_EBTC_LBTC",
        "AVALON_USDA",
        "AVALON_SKAIA",
        "AVALON_LORENZO",
        "AVALON_INNOVATION",
        "AVALON_UBTC",
        "AVALON_OBTC",
        "AVALON_BEETS",
        "AVALON_UNIIOTX",
        "AVALON_BOB",
        "AVALON_STBTC",
        "AVALON_WBTC",
        "AVALON_LBTC",
        "AVALON_XAUM",
        "AVALON_LISTA",
        "AVALON_USDX",

        // High-risk Aave V3 forks — PoolAddressesProvider owned by a single EOA, which can
        // upgrade the pool impl and drain composer approvers via the flash-loan callback.
        "BETTER_BANK", // PulseChain, EOA admin
        "BETTER_BANK_ATROPA", // PulseChain, EOA admin
        "LAYERBANK_V3", // BOB / Plume / Hemi — all EOA admin

        // Radiant — project winding down; removed on every chain.
        "RADIANT_V2",

        // EOA-governed Aave forks — provider owner is a single EOA that can upgrade the
        // pool impl and drain composer approvers. Removed everywhere they appear.
        "PAC", // blast
        "SEISMIC", // blast
        "RMM", // gnosis
        "LENDOS", // hemi
        "KLAP", // kaia
        "RHOMBUS", // kaia
        "MOLEND", // mode
        "MERIDIAN", // taiko + telos (both EOA)
        "HANA", // taiko

        // Sonic — remove.
        "MAGSIN",

        // ────────────────────────────────────────────────────────────────────────
        // Governance-policy removals (fork trust audit, 2026-07).
        // Policy: trust only the original Aave DAO deployments or forks with strong
        // governance. The only exception deliberately KEPT despite failing the bar is
        // PHIAT (main lender on PulseChain, kept on Pulse; still excluded on Ethereum
        // below). MOOLA, and COLEND/FATHOM (frozen flash loans), were removed (below).
        // ────────────────────────────────────────────────────────────────────────
        // Confirmed single-EOA / cosmetic-timelock control — an EOA can upgrade the
        // pool impl and drain composer approvers via the flash-loan callback:
        "SAKE", // Soneium — single EOA behind a 10-min timelock (verified on-chain)
        "SAKE_ASTAR", // Soneium — same EOA-controlled stack as SAKE
        "VALAS", // BNB — anon team, self-described "no governance", moribund
        "KLAYBANK", // Kaia — anon, opaque admin
        "NEREUS", // Avalanche — exploited (2022), opaque admin, defunct
        "LORE", // Scroll — anon, winding down, ~$4k TVL
        // New / obscure forks, unverified governance, no reputable audit:
        "HYPERYIELD", // HyperEVM — ZeroLend-derived, no public audit
        "HYPURRFI", // HyperEVM — semi-anon, sunsetting (Euler takeover)
        "NEVERLAND", // Monad — early; only custom modules audited (1 Critical + 3 High)
        "YEI_SOLV", // Sei — 2nd market is multisig-only, no timelock (YEI main market kept)
        // Previously-exploited forks:
        "AGAVE", // Gnosis — 1hive multisig; ~$5.5M reentrancy exploit (2022), near-defunct
        "MOOLA", // Celo — 4/10 multisig, no timelock; ~$8.4M oracle exploit (2022), ~$0.9M TVL near-dormant; Celo keeps Aave V3
        // Multisig+timelock (Byte Masons / Conclave) — below the strong-governance bar
        // but NOT single-EOA; removed per policy, easily re-added if desired:
        "IRONCLAD", // Mode — Feb-2025 Ionic bad-debt spillover
        "GRANARY", // multi-chain — <4-signer multisig + ~48h timelock, no DAO
        // Removed on every chain: EOA-governed on HyperEVM/XDC, and on Base the same
        // assets are already covered (better) by other lenders — so drop it there too
        // to shrink the trusted flash-loan set. Leaves Base with no Aave V2 flash source.
        "PRIME_FI",
        // Flash loans frozen / disabled at the protocol — dropped from the trusted
        // flash-loan set before the composers are made immutable (2026-07).
        "COLEND", // Core — flash loans frozen
        "COLEND_LSTBTC", // Core — flash loans frozen
        "FATHOM", // XDC — flash loans frozen/disabled
    ] as string[],
    BY_CHAIN: {
        // Ethereum mainnet — drop niche Aave V2/V3 forks that are rarely flash-loaned from the composer.
        // (ZeroLend, Avalon and Radiant are now covered by ALWAYS.)
        "1": [
            // Aave V2 fork — restricted; only the canonical Aave V2 flash-loan source is kept on mainnet.
            // (PHIAT is kept on PulseChain — its main deployment — but not on Ethereum.)
            "PHIAT",
            // Kinza is EOA-governed on mainnet (timelocked only on BNB, which is kept).
            "KINZA",
        ],
        // Mantle — Kinza is EOA-governed here (kept on BNB where it is timelocked).
        "5000": [
            "KINZA",
        ],
        // (PRIME_FI is now removed on every chain via ALWAYS — see above.)
        // Abstract (2741) — Aave V3 fork restricted; keep only the canonical Aave V3 flash-loan source.
        "2741": [
            "KONA_LEND",
        ],
    } as Record<string, string[]>,
};

export function isLenderExcluded(chainId: string, lenderName: string): boolean {
    if (FLASH_LOAN_LENDER_EXCLUSIONS.ALWAYS.includes(lenderName)) return true;
    const chainExclusions = FLASH_LOAN_LENDER_EXCLUSIONS.BY_CHAIN[chainId];
    return chainExclusions !== undefined && chainExclusions.includes(lenderName);
}
