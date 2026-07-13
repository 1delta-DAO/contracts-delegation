/**
 * Curated allowlist of Uniswap-V3-style forks that are safe to use as flash-loan sources.
 *
 * The V3 flash callback trusts a pool WITHOUT a per-pool whitelist: it recomputes the pool's
 * CREATE2 address from (factory, token0, token1, fee) and requires `caller()` to match. This is
 * only sound for **immutable, factory-deployed pools** — if the pool sits behind an upgradeable
 * proxy/beacon, a malicious upgrade could make a "valid" address behave maliciously.
 *
 * Since `@1delta/dex-registry` has no proxy flag, we derive immutability from `forkType` plus an
 * explicit proxy/clone denylist. Keep this list conservative: exclude anything not confirmed
 * immutable.
 */

// forkType values whose pools are deterministic, immutable CREATE2 deployments.
// (Ramses / ve(3,3) clone pools are intentionally omitted.)
const IMMUTABLE_FORK_TYPES = new Set<string>([
    "Classic",
    "Pancake",
    "AlgebraV3",
    "AlgebraV3_9",
    "AlgebraV4",
    "AlgebraV4_1",
    "AlgebraV4_2",
]);

// Forks whose forkType is "immutable" above but whose pools are actually proxy/beacon/clone
// deployments (upgradeable) — excluded explicitly.
const PROXY_FORK_DENYLIST = new Set<string>([
    "AERODROME_SLIPSTREAM", // Slipstream pools sit behind an upgradeable beacon
    "VELODROME_V3", // Velodrome Slipstream — same beacon-clone model
    "SHADOW_CL", // Ramses-family clone
    "CLEOPATRA", // Ramses-family clone
    "RAMSES_V2", // Ramses-family clone
    "PHARAOH_CL", // Ramses-family clone
    "NILE_CL", // Ramses-family clone
]);

/**
 * True if a Uniswap-V3 fork may be used as a flash-loan source (immutable, non-proxy pools).
 * @param forkName registry key, e.g. "UNISWAP_V3"
 * @param forkType effective forkType for the chain (forkType[chain] ?? forkType.default)
 * @param codeHash effective init-code hash for the chain (must be a real hash, not an OVERRIDE sentinel)
 */
export function isImmutableUniV3FlashFork(forkName: string, forkType: string, codeHash: string): boolean {
    if (PROXY_FORK_DENYLIST.has(forkName)) return false;
    if (!IMMUTABLE_FORK_TYPES.has(forkType)) return false;
    // require a plain CREATE2 init-code hash (32-byte hex). OVERRIDE/EXCLUDE sentinels are not hashes.
    if (!/^0x[0-9a-fA-F]{64}$/.test(codeHash)) return false;
    return true;
}
