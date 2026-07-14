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

import {UNISWAP_V3_FORKS} from "@1delta/dex-registry";
import {getAddress} from "ethers/lib/utils";
import {DEX_TO_CHAINS_EXCLUSIONS} from "./dex/blacklists";

// forkType values whose pools are deterministic, immutable CREATE2 deployments.
// (Ramses / ve(3,3) clone pools are intentionally omitted.)
const IMMUTABLE_FORK_TYPES = new Set<string>(["Classic", "Pancake", "AlgebraV3", "AlgebraV3_9", "AlgebraV4", "AlgebraV4_1", "AlgebraV4_2"]);

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

/**
 * Map a fork's (swap) callbackSelector prefix to its flash-callback family.
 * Only the primary selector per family (the standard flash callback) is accepted; forks with
 * variant selectors are skipped (their flash callback is unknown). Family ids match the Solidity
 * template: Classic=0, Pancake=1, Algebra=2.
 */
export const V3_FLASH_FAMILY: {[selectorPrefix: string]: {id: number; isAlgebra: boolean}} = {
    "0xfa461e33": {id: 0, isAlgebra: false}, // Classic  -> uniswapV3FlashCallback
    "0x23a69e75": {id: 1, isAlgebra: false}, // Pancake  -> pancakeV3FlashCallback
    "0x2c8958f6": {id: 2, isAlgebra: true}, // Algebra  -> algebraFlashCallback
};

export interface UniV3FlashData {
    entityName: string;
    forkId: string;
    factory: string;
    codeHash: string;
    familyId: number;
    isAlgebra: boolean;
}

/**
 * ff-factory constant VALUE (`0xff | factory | algebra-marker`) written into the callback.
 * The low 11 bytes are a marker the Solidity reads to pick the CREATE2 salt shape (Algebra pools
 * omit the fee); they are overwritten before hashing. Single source of truth shared by the
 * generator (which emits the constant) and the verifier (which pins it to the registry).
 */
export function ffFactoryConstantValue(factory: string, isAlgebra: boolean): string {
    const addr = getAddress(factory).slice(2).toLowerCase();
    const suffix = isAlgebra ? "ffffffffffffffffffffff" : "0000000000000000000000"; // 11 bytes
    return `0xff${addr}${suffix}`;
}

/**
 * Collect the Uniswap-V3-style flash-loan sources configured for `chain`, exactly as the
 * generator emits them (immutable, factory-deployed, standard flash selector, not excluded).
 * Single source of truth shared by `createFlashLoanCallbacks.ts` (writes the constants) and
 * `verifyUniV3FlashConstants.ts` (pins them to the registry).
 */
export function collectUniV3FlashForks(chain: string): UniV3FlashData[] {
    const out: UniV3FlashData[] = [];
    Object.entries(UNISWAP_V3_FORKS).forEach(([dex, maps]: [string, any]) => {
        const factory = maps.factories?.[chain];
        if (!factory) return;
        if (DEX_TO_CHAINS_EXCLUSIONS[dex]?.includes(chain)) return;
        const forkType = maps.forkType?.[chain] ?? maps.forkType?.default;
        const codeHash = maps.codeHash?.[chain] ?? maps.codeHash?.default;
        if (!isImmutableUniV3FlashFork(dex, forkType, codeHash)) return;
        const fam = V3_FLASH_FAMILY[(maps.callbackSelector ?? "").slice(0, 10)];
        if (!fam) return; // only forks whose flash callback selector is standard
        out.push({
            entityName: dex,
            forkId: String(maps.forkId),
            factory,
            codeHash,
            familyId: fam.id,
            isAlgebra: fam.isAlgebra,
        });
    });
    return out;
}
