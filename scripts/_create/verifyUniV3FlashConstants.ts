/**
 * Verify that the generated Uniswap-V3 flash-loan callbacks are faithful to the registry.
 *
 * The V3 flash callback trusts ANY pool whose CREATE2 address (derived from a hardcoded
 * factory + init-code hash) equals `caller()`. Security therefore rests entirely on those
 * hardcoded constants being correct. This check pins every generated `UniV3Callback.sol`
 * constant to `@1delta/dex-registry` (the same source the generator reads), catching:
 *   - stale files (registry changed, generator not re-run),
 *   - hand-edits to generated callbacks,
 *   - wrong factory / init-code hash / Algebra salt-marker,
 *   - a fork placed under the wrong callback family or forkId,
 *   - forks that are present but should not be (or missing but should be).
 *
 * Deterministic, no RPC — safe for CI. It does NOT assert the registry itself is correct
 * (that is validated on-chain by the swap-side derivation tests, which share these values).
 *
 * Run: `pnpm verify-univ3-flash-constants` (or `tsx scripts/_create/verifyUniV3FlashConstants.ts`)
 */

import * as fs from "fs";
import {CREATE_CHAIN_IDS, getChainKey} from "./config";
import {collectUniV3FlashForks, ffFactoryConstantValue, UniV3FlashData} from "./uniV3FlashForks";
import {fetchLenderMetaFromDirAndInitialize} from "./utils";

const callbackPath = (chain: string) => `./contracts/1delta/composer/chains/${getChainKey(chain)}/flashLoan/callbacks/UniV3Callback.sol`;

/** Slice the `{ ... }` block whose opening brace is at `openIdx`, honouring nesting. */
function sliceBlock(src: string, openIdx: number): {inner: string; end: number} {
    let depth = 0;
    for (let i = openIdx; i < src.length; i++) {
        if (src[i] === "{") depth++;
        else if (src[i] === "}") {
            depth--;
            if (depth === 0) return {inner: src.slice(openIdx + 1, i), end: i};
        }
    }
    throw new Error("unbalanced braces in UniV3Callback.sol");
}

/** Extract the inner body of each `case <familyId> { ... }` arm of the outer `switch family`. */
function familyBlocks(src: string): {[familyId: number]: string} {
    const res: {[familyId: number]: string} = {};
    let i = src.indexOf("switch family");
    if (i < 0) return res;
    i += "switch family".length;
    while (i < src.length) {
        const rest = src.slice(i);
        const ws = /\S/.exec(rest);
        if (!ws) break;
        i += ws.index;
        const caseM = /^case\s+(\d+)\s*\{/.exec(src.slice(i));
        const defM = /^default\s*\{/.exec(src.slice(i));
        if (caseM) {
            const brace = src.indexOf("{", i);
            const {inner, end} = sliceBlock(src, brace);
            res[Number(caseM[1])] = inner;
            i = end + 1;
        } else if (defM) {
            const brace = src.indexOf("{", i);
            i = sliceBlock(src, brace).end + 1;
            break; // the outer `default` closes `switch family`
        } else {
            break;
        }
    }
    return res;
}

const collapse = (s: string) => s.replace(/\s+/g, " ").trim();

function verifyChain(chain: string): string[] {
    const errs: string[] = [];
    const expected = collectUniV3FlashForks(chain);
    const filePath = callbackPath(chain);
    const exists = fs.existsSync(filePath);

    if (expected.length === 0) {
        if (exists) errs.push(`${filePath}: file exists but registry configures no UniV3 flash forks for this chain`);
        return errs;
    }
    if (!exists) {
        errs.push(
            `${filePath}: MISSING — registry configures ${expected.length} UniV3 flash fork(s) (${expected.map((f) => f.entityName).join(", ")})`
        );
        return errs;
    }

    const src = fs.readFileSync(filePath, "utf8");
    const norm = collapse(src);
    const fams = familyBlocks(src);

    // 1. every expected fork's constants + switch arm are present and correct
    for (const f of expected) {
        const expFf = ffFactoryConstantValue(f.factory, f.isAlgebra).toLowerCase();
        const ffM = new RegExp(`bytes32 private constant ${f.entityName}_FF_FACTORY = (0x[0-9a-fA-F]+);`).exec(src);
        if (!ffM) errs.push(`${chain}/${f.entityName}: FF_FACTORY constant not found`);
        else if (ffM[1].toLowerCase() !== expFf)
            errs.push(`${chain}/${f.entityName}: FF_FACTORY mismatch\n    file:     ${ffM[1].toLowerCase()}\n    registry: ${expFf}`);

        const chM = new RegExp(`bytes32 private constant ${f.entityName}_CODE_HASH = (0x[0-9a-fA-F]+);`).exec(src);
        if (!chM) errs.push(`${chain}/${f.entityName}: CODE_HASH constant not found`);
        else if (chM[1].toLowerCase() !== f.codeHash.toLowerCase())
            errs.push(
                `${chain}/${f.entityName}: CODE_HASH mismatch\n    file:     ${chM[1].toLowerCase()}\n    registry: ${f.codeHash.toLowerCase()}`
            );

        // arm exists at all (forkId + wiring to this fork's constants)
        const armNorm = collapse(`case ${f.forkId} { ffFactoryAddress := ${f.entityName}_FF_FACTORY codeHash := ${f.entityName}_CODE_HASH }`);
        if (!norm.includes(armNorm)) errs.push(`${chain}/${f.entityName}: switch arm (forkId ${f.forkId}) not found or mis-wired`);

        // arm sits under the CORRECT callback family (Classic=0/Pancake=1/Algebra=2)
        const famBody = fams[f.familyId];
        if (famBody === undefined) errs.push(`${chain}/${f.entityName}: family ${f.familyId} block missing from 'switch family'`);
        else if (!collapse(famBody).includes(armNorm))
            errs.push(`${chain}/${f.entityName}: fork is not under family ${f.familyId} (wrong callback entrypoint)`);
    }

    // 2. no EXTRA forks in the file beyond what the registry configures
    const expectedNames = new Set(expected.map((f) => f.entityName));
    const nameRe = /bytes32 private constant ([A-Z0-9_]+)_FF_FACTORY =/g;
    let m: RegExpExecArray | null;
    while ((m = nameRe.exec(src)) !== null) {
        if (!expectedNames.has(m[1])) errs.push(`${chain}/${m[1]}: extra fork constant in file, not configured in registry`);
    }

    return errs;
}

async function main() {
    // `getChainKey` reads the data-sdk chain registry, which must be initialized first
    // (same bootstrap the generator performs).
    await fetchLenderMetaFromDirAndInitialize();

    const allErrors: string[] = [];
    let chainsWithForks = 0;
    let forkCount = 0;

    for (const chain of CREATE_CHAIN_IDS) {
        const expected: UniV3FlashData[] = collectUniV3FlashForks(chain);
        if (expected.length > 0) {
            chainsWithForks++;
            forkCount += expected.length;
        }
        allErrors.push(...verifyChain(chain));
    }

    if (allErrors.length > 0) {
        console.error(`\n❌ UniV3 flash-constant verification FAILED (${allErrors.length} issue(s)):\n`);
        allErrors.forEach((e) => console.error(`  - ${e}`));
        console.error("");
        process.exit(1);
    }

    console.log(`✅ UniV3 flash-loan constants verified: ${forkCount} fork(s) across ${chainsWithForks} chain(s) match @1delta/dex-registry.`);
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
