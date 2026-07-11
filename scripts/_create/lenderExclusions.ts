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
    ] as string[],
    BY_CHAIN: {
        // Ethereum mainnet — drop niche Aave V2/V3 forks that are rarely flash-loaned from the composer.
        // (ZeroLend, Avalon and Radiant are now covered by ALWAYS.)
        "1": [
            // Aave V2 fork — restricted; only the canonical Aave V2 flash-loan source is kept on mainnet.
            "PHIAT",
            // Aave V2 forks — primarily deployed on other chains (Avalanche / Optimism / Arbitrum).
            "GRANARY",
            // Kinza is EOA-governed on mainnet (timelocked only on BNB, which is kept).
            "KINZA",
        ],
        // Mantle — Kinza is EOA-governed here (kept on BNB where it is timelocked).
        "5000": [
            "KINZA",
        ],
        // HyperEVM — Prime Fi is EOA-governed here (kept on Base where it is contract-governed).
        "999": [
            "PRIME_FI",
        ],
        // XDC — Prime Fi is EOA-governed here (kept on Base where it is contract-governed).
        "50": [
            "PRIME_FI",
        ],
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
