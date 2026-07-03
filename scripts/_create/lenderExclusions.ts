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
    ] as string[],
    BY_CHAIN: {
        // Ethereum mainnet — drop niche Aave V2/V3 forks that are rarely flash-loaned from the composer.
        "1": [
            // Aave V3 forks — low volume on mainnet, available on other chains if needed.
            "ZEROLEND_STABLECOINS_RWA",
            "ZEROLEND_ETH_LRTS",
            "ZEROLEND_BTC_LRTS",
            "AVALON_SOLVBTC",
            "AVALON_SWELLBTC",
            "AVALON_PUMPBTC",
            "AVALON_EBTC_LBTC",
            // Aave V2 fork — restricted; only the canonical Aave V2 flash-loan source is kept on mainnet.
            "PHIAT",
            // Aave V2 forks — primarily deployed on other chains (Avalanche / Optimism / Arbitrum).
            "GRANARY",
            "RADIANT_V2",
        ],
        // Abstract (2741) — Aave V3 fork restricted; keep only the canonical Aave V3 flash-loan source.
        "2741": [
            "KONA_LEND",
        ],
        // Plume (98866) — Aave V3 fork restricted; keep only the canonical Aave V3 flash-loan source.
        "98866": [
            "AVALON",
        ],
    } as Record<string, string[]>,
};

export function isLenderExcluded(chainId: string, lenderName: string): boolean {
    if (FLASH_LOAN_LENDER_EXCLUSIONS.ALWAYS.includes(lenderName)) return true;
    const chainExclusions = FLASH_LOAN_LENDER_EXCLUSIONS.BY_CHAIN[chainId];
    return chainExclusions !== undefined && chainExclusions.includes(lenderName);
}
