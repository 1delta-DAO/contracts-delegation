/**
 * Emits a concrete example pool address (with on-chain code) for every allowlisted
 * Uniswap-V3-style flash-loan fork on every generated chain — as a Markdown table for auditors.
 *
 * For each fork it computes a pool address the SAME way the callback validates it —
 * `CREATE2(factory, keccak256(token0, token1[, fee]), initCodeHash)` — for the chain's
 * wrapped-native / USD pair, and reports the first fee tier whose address has code, together with
 * the code size. A non-empty code size at a deterministically-derived address is the reassurance:
 * the factory really deploys the canonical, immutable pool the validation trusts.
 *
 * Run:  npx tsx scripts/sample-univ3-pools.ts  [> docs/uniswap-v3-example-pools.md]
 */
import {ethers} from "ethers";
import {UNISWAP_V3_FORKS} from "@1delta/dex-registry";
import {isImmutableUniV3FlashFork} from "./_create/uniV3FlashForks";
import {CREATE_CHAIN_IDS, getChainKey} from "./_create/config";
import {chains} from "@1delta/data-sdk";
import {fetchLenderMetaFromDirAndInitialize} from "./_create/utils";

const PRIMARY = new Set(["0xfa461e33", "0x23a69e75", "0x2c8958f6"]);
const CLASSIC_FEES = [3000, 500, 100, 10000, 2500, 450, 250, 200];
const TIMEOUT = 12_000;
const CONCURRENCY = 10;

// wrapped-native / USD sample pair per chainId (same set the verifier uses)
const PAIRS: {[id: string]: [string, string]} = {
    "1": ["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"],
    "10": ["0x4200000000000000000000000000000000000006", "0x7f5c764cbc14f9669b88837ca1490cca17c31607"],
    "14": ["0x1d80c49bbbcd1c0911346656b529df9e5c2f783d", "0xfbda5f676cb37624f28265a144a48b0d6e87d3b6"],
    "25": ["0xf44acfdc916898449e39062934c2b496799b6abe", "0xf951ec28187d9e5ca673da8fe6757e6f0be5f77c"],
    "40": ["0x7c598c96d02398d89fbcb9d41eab3df0c16f227d", "0x8d97cea50351fb4329d591682b148d43a0c3611b"],
    "50": ["0xdc2393dc10734bf153153038943a5deb42b209cd", "0xb25cb6a275a8d6a613228fb161eb3627b50eb696"],
    "56": ["0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c", "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d"],
    "100": ["0xe91d153e0b41518a2ce8dd3d7944fa863463a97d", "0xddafbb505ad214d7b80b1f830fccc89b60fb7a83"],
    "130": ["0x4200000000000000000000000000000000000006", "0x078d782b760474a361dda0af3839290b0ef57ad6"],
    "137": ["0x7ceb23fd6bc0add59e62ac25578270cff1b9f619", "0x2791bca1f2de4661ed88a30c99a7a9449aa84174"],
    "143": ["0xee8c0e9f1bffb4eb878d8f15f368a02a35481242", "0x754704bc059f8c67012fed69bc8a327a5aafb603"],
    "146": ["0x50c42deacd8fc9773493ed674b675be577f2634b", "0x29219dd400f2bf60e5a23d13be72b486d4038894"],
    "169": ["0x0dc808adce2099a9f62aa87d9670745aba741746", "0xb73603c5d87fa094b7314c74ace2e64d165016fb"],
    "196": ["0xe538905cf8410324e03a5a23c1c177a474d59b2b", "0x74b7f16337b8972027f6196a17a631ac6de26d22"],
    "250": ["0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83", "0x2f733095b80a04b38b0d10cc884524a3d09b836a"],
    "988": ["0x783129e4d7ba0af0c896c239e57c06df379aae8c", "0x8a2b28364102bea189d99a475c494330ef2bdd0b"],
    "999": ["0x5555555555555555555555555555555555555555", "0xb88339cb7199b77e23db6e890353e22632ba630f"],
    "1088": ["0x420000000000000000000000000000000000000a", "0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34"],
    "1116": ["0x191e94fa59739e188dce837f7f6978d84727ad01", "0x900101d06a7426441ae63e9ab3b9b0f63be145f1"],
    "1135": ["0x4200000000000000000000000000000000000006", "0xf242275d3a6527d877f2c927a82d9b057609cc71"],
    "1284": ["0xacc15dc74880c9944775448304b263d191c6077f", "0x8f552a71efe5eefc207bf75485b356a0b3f01ec9"],
    "1329": ["0xe30fedd158a2e3b13e9badaeabafc5516e95e8c7", "0x3894085ef7ff0f0aedf52e2a2704928d1ec074f1"],
    "1672": ["0x1f4b7011ee3d53969bb67f59428a9ec0477856e9", "0xc879c018db60520f4355c26ed1a6d572cdac1815"],
    "1868": ["0x4200000000000000000000000000000000000006", "0xba9986d2381edf1da03b0b9c1f8b00dc4aacc369"],
    "2345": ["0x3a1293bdb83bbbdd5ebf4fac96605ad2021bbc0f", "0x3022b87ac063de95b1570f46f5e470f8b53112d8"],
    "2741": ["0x3439153eb7af838ad19d56e1571fbd09333c2809", "0x84a71ccd554cc1b02749b35d22f684cc8ec987e1"],
    "2818": ["0x5300000000000000000000000000000000000011", "0xe34c91815d7fc18a9e2148bcd4241d0a5848b693"],
    "4326": ["0x4200000000000000000000000000000000000006", "0xfafddbb3fc7688494971a79cc65dca3ef82079e7"],
    "4663": ["0x0bd7d308f8e1639fab988df18a8011f41eacad73", "0x5fc5360d0400a0fd4f2af552add042d716f1d168"],
    "5000": ["0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8", "0x09bc4e0d864854c6afb6eb9a9cdf58ac190d0df9"],
    "8217": ["0x98a8345bb9d3dda9d808ca1c9142a28f6b0430e1", "0x608792deb376cce1c9fa4d0e6b7b44f507cffa6a"],
    "8453": ["0x4200000000000000000000000000000000000006", "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"],
    "9745": ["0x9895d81bb462a195b4922ed7de0e3acd007c32cb", "0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb"],
    "34443": ["0x4200000000000000000000000000000000000006", "0xd988097fb8612cc24eec14542bc03424c656005f"],
    "42161": ["0x82af49447d8a07e3bd95bd0d56f35241523fbab1", "0xaf88d065e77c8cc2239327c5edb3a432268e5831"],
    "42220": ["0x2def4285787d58a2f811af24755a8150622f4361", "0xceba9300f2b948710d2653dd7b07f33a8b32118c"],
    "42793": ["0xfc24f770f94edbca6d6f885e12d4317320bcb401", "0x796ea11fa2dd751ed01b53c372ffdb4aaa8f00f9"],
    "43111": ["0x4200000000000000000000000000000000000006", "0xad11a8beb98bbf61dbb1aa0f6d6f2ecd87b35afa"],
    "43114": ["0x49d5c2bdffac6ce2bfdb6640f4f80f226bc10bab", "0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e"],
    "57073": ["0x4200000000000000000000000000000000000006", "0xf1815bd50389c46847f0bda824ec8da914045d14"],
    "59144": ["0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f", "0x176211869ca2b568f2a7d4ee941e073a821ee1ff"],
    "60808": ["0x4200000000000000000000000000000000000006", "0xe75d0fb2c24a55ca1e3f96781a2bcc7bdba058f0"],
    "80094": ["0x2f6f07cdcf3588944bf4c42ac74ff24bf56e7590", "0x549943e04f40284185054145c6e4e9568c1d3241"],
    "81457": ["0x4300000000000000000000000000000000000004", "0x4300000000000000000000000000000000000003"],
    "98866": ["0xca59ca09e5602fae8b629dee83ffa819741f14be", "0x78add880a697070c1e765ac44d65323a0dcce913"],
    "167000": ["0xa51894664a773981c6c112c43ce576f315d5b1b6", "0x07d83526730c7438048d55a4fc0b850e2aab6f0b"],
    "534352": ["0x5300000000000000000000000000000000000004", "0x06efdbff2a14a7c8e15944d1f4a48f9f95f663a4"],
    "21000000": ["0x485bbc4f98c071c9bd74ac255262e61f866f071a", "0xdf0b24095e15044538866576754f3c964e902ee6"],
};

function withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
    return Promise.race([p, new Promise<T>((_, rej) => setTimeout(() => rej(new Error("timeout")), ms))]);
}
// reliable public RPCs for chains whose registry default is flaky/rate-limited
const RPC_OVERRIDES: {[id: string]: string} = {
    "1": "https://ethereum-rpc.publicnode.com",
    "137": "https://polygon-bor-rpc.publicnode.com",
    "43114": "https://avalanche-c-chain-rpc.publicnode.com",
    "250": "https://fantom.drpc.org",
    "1284": "https://rpc.api.moonbeam.network",
    "1088": "https://andromeda.metis.io/?owner=1088",
    "8453": "https://base-mainnet.public.blastapi.io",
    "747474": "https://rpc.katana.network",
    "42220": "https://forno.celo.org",
};
const providerCache: {[id: string]: ethers.providers.JsonRpcProvider | null} = {};
function providerFor(cd: any, id: string) {
    if (id in providerCache) return providerCache[id];
    const rpc =
        RPC_OVERRIDES[id] || (cd[id]?.rpc || []).find((u: string) => /^https/.test(u) && !/\$\{|_KEY|INFURA|ALCHEMY/i.test(u));
    return (providerCache[id] = rpc ? new ethers.providers.JsonRpcProvider(rpc) : null);
}
function poolAddress(factory: string, codeHash: string, tA: string, tB: string, fee?: number) {
    const [a, b] = tA.toLowerCase() < tB.toLowerCase() ? [tA, tB] : [tB, tA];
    const salt =
        fee === undefined
            ? ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "address"], [a, b]))
            : ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "address", "uint24"], [a, b, fee]));
    return ethers.utils.getCreate2Address(ethers.utils.getAddress(factory), salt, codeHash);
}

async function runPool<T>(items: T[], limit: number, w: (i: T) => Promise<void>) {
    let i = 0;
    await Promise.all(
        Array.from({length: Math.min(limit, items.length)}, async () => {
            while (i < items.length) await w(items[i++]).catch(() => {});
        })
    );
}

async function main() {
    await fetchLenderMetaFromDirAndInitialize();
    const cd = chains();
    const gen = new Set(CREATE_CHAIN_IDS.map(String));
    interface D {chainId: string; dex: string; factory: string; codeHash: string; isAlgebra: boolean}
    const deps: D[] = [];
    for (const [dex, maps] of Object.entries<any>(UNISWAP_V3_FORKS)) {
        for (const [chainId, factory] of Object.entries<any>(maps.factories || {})) {
            if (!gen.has(chainId)) continue;
            const forkType = maps.forkType?.[chainId] ?? maps.forkType?.default;
            const codeHash = maps.codeHash?.[chainId] ?? maps.codeHash?.default;
            if (!isImmutableUniV3FlashFork(dex, forkType, codeHash)) continue;
            if (!PRIMARY.has((maps.callbackSelector || "").slice(0, 10))) continue;
            deps.push({chainId, dex, factory, codeHash, isAlgebra: String(forkType).startsWith("Algebra")});
        }
    }

    const rows: {chainKey: string; dex: string; factory: string; pool: string; size: number; fee: string}[] = [];
    const misses: string[] = [];
    await runPool(deps, CONCURRENCY, async (d) => {
        const p = providerFor(cd, d.chainId);
        const pair = PAIRS[d.chainId];
        const key = (() => {
            try {
                return getChainKey(d.chainId);
            } catch {
                return d.chainId;
            }
        })();
        if (!p || !pair) {
            misses.push(`${key} / ${d.dex} (no rpc or pair)`);
            return;
        }
        const fees = d.isAlgebra ? [undefined] : CLASSIC_FEES;
        for (const fee of fees) {
            const pool = poolAddress(d.factory, d.codeHash, pair[0], pair[1], fee as number | undefined);
            let code: string;
            try {
                code = await withTimeout(p.getCode(pool), TIMEOUT);
            } catch {
                continue;
            }
            const sz = (code.length - 2) / 2;
            if (sz > 0) {
                rows.push({chainKey: key, dex: d.dex, factory: d.factory, pool, size: sz, fee: fee === undefined ? "—" : String(fee)});
                return;
            }
        }
        misses.push(`${key} / ${d.dex}`);
    });

    rows.sort((a, b) => (a.chainKey + a.dex).localeCompare(b.chainKey + b.dex));
    console.log(`| Chain | Fork | Fee | Example pool (has code) | Pool code size |`);
    console.log(`|---|---|---|---|---|`);
    for (const r of rows) console.log(`| ${r.chainKey} | ${r.dex} | ${r.fee} | \`${r.pool}\` | ${r.size} B |`);
    console.log(`\n_${rows.length} of ${deps.length} fork-deployments have a live wnative/USD example pool with code._`);
    if (misses.length) console.log(`\n_No wnative/USD pool sampled for: ${misses.sort().join(", ")} (small forks; factory immutability still verified separately)._`);
}
main().catch((e) => {
    console.error(e);
    process.exit(1);
});
