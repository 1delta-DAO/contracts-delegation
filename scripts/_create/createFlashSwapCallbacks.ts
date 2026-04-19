import {getAddress} from "ethers/lib/utils";
import * as fs from "fs";
import {templateSwapCallbacks} from "./templates/flashSwap/swapCallbacks";
import {templateUniV4} from "./templates/flashSwap/uniV4Callback";
import {CREATE_CHAIN_IDS, getChainKey} from "./config";
import {composerTestImports} from "./templates/test/composerImport";

import {UNISWAP_V4_FORKS} from "@1delta/dex-registry";
import {DEX_TO_CHAINS_EXCLUSIONS} from "./dex/blacklists";
import {fetchLenderMetaFromDirAndInitialize} from "./utils";

/** simple address import */
function createConstant(pool: string, lender: string) {
    return `address private constant ${lender} = ${getAddress(pool)};\n`;
}

/** switch case for uni V4s and balancer V3 */
function createCaseUniV4BalV3(entityName: string, entityId: string) {
    return `case ${entityId} {
        if xor(caller(), ${entityName}) {
            mstore(0, INVALID_CALLER)
            revert(0, 0x4)
        }
    }\n`;
}

/** switch case for uni V4s and balancer V3 solo */
function createCaseUniV4BalV3Solo(entityName: string) {
    return `
        if xor(caller(), ${entityName}) {
            mstore(0, INVALID_CALLER)
            revert(0, 0x4)
        }
    `;
}

interface DexIdData {
    entityName: string;
    entityId: string;
    pool: string;
}

/** List of filenames we no longer emit — removed on disk if present */
const STALE_SWAP_CALLBACK_FILES = ["UniV2Callback.sol", "UniV3Callback.sol", "DodoV2Callback.sol", "BalancerV3Callback.sol"];

async function main() {
    const chainsUsed = CREATE_CHAIN_IDS;
    await fetchLenderMetaFromDirAndInitialize();
    for (let i = 0; i < chainsUsed.length; i++) {
        const chain = chainsUsed[i];
        const key = getChainKey(chain);

        let dexIdsUniV4: DexIdData[] = [];
        Object.entries(UNISWAP_V4_FORKS).forEach(([dex, maps]) => {
            Object.entries(maps.pm).forEach(([chains, address]) => {
                if (chains === chain) {
                    if (!DEX_TO_CHAINS_EXCLUSIONS[dex]?.includes(chain))
                        dexIdsUniV4.push({
                            entityName: dex,
                            entityId: maps.forkId,
                            pool: address,
                        });
                }
            });
        });

        /** Uni V4 */
        let constantsDataV4 = ``;
        let switchCaseContentV4 = ``;
        dexIdsUniV4 = dexIdsUniV4.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));

        if (dexIdsUniV4.length === 1) {
            const {pool, entityName} = dexIdsUniV4[0];
            constantsDataV4 += createConstant(pool, entityName);
            switchCaseContentV4 += createCaseUniV4BalV3Solo(entityName);
        } else if (dexIdsUniV4.length > 1) {
            switchCaseContentV4 += `switch poolId`;
            dexIdsUniV4.forEach(({pool, entityName, entityId}) => {
                constantsDataV4 += createConstant(pool, entityName);
                switchCaseContentV4 += createCaseUniV4BalV3(entityName, entityId);
            });
            switchCaseContentV4 += `
                default {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }
            `;
        }

        /** Write files */

        const flashSwapCallbackDir = `./contracts/1delta/composer/chains/${key}/flashSwap/callbacks/`;
        const flashSwapDir = `./contracts/1delta/composer/chains/${key}/flashSwap/`;

        // Remove stale V2/V3/Dodo/BalV3 swap-callback files (no longer emitted)
        if (fs.existsSync(flashSwapCallbackDir)) {
            for (const fileName of STALE_SWAP_CALLBACK_FILES) {
                const p = flashSwapCallbackDir + fileName;
                if (fs.existsSync(p)) fs.rmSync(p);
            }
        }

        if (dexIdsUniV4.length > 0) {
            fs.mkdirSync(flashSwapCallbackDir, {recursive: true});
            const filePathV4 = flashSwapCallbackDir + "UniV4Callback.sol";
            fs.writeFileSync(filePathV4, templateUniV4(constantsDataV4, switchCaseContentV4, dexIdsUniV4.length > 1));

            const filePathSwapCallbacks = flashSwapDir + "SwapCallbacks.sol";
            fs.writeFileSync(filePathSwapCallbacks, templateSwapCallbacks(true));
        } else {
            // No UniV4 on this chain — remove any lingering flashSwap files so we don't leave orphans
            const staleUniV4 = flashSwapCallbackDir + "UniV4Callback.sol";
            if (fs.existsSync(staleUniV4)) fs.rmSync(staleUniV4);
            const staleSwapCallbacks = flashSwapDir + "SwapCallbacks.sol";
            if (fs.existsSync(staleSwapCallbacks)) fs.rmSync(staleSwapCallbacks);
            // If the callbacks dir is now empty, remove it
            if (fs.existsSync(flashSwapCallbackDir) && fs.readdirSync(flashSwapCallbackDir).length === 0) {
                fs.rmdirSync(flashSwapCallbackDir);
            }
            // If the flashSwap dir is now empty, remove it
            if (fs.existsSync(flashSwapDir) && fs.readdirSync(flashSwapDir).length === 0) {
                fs.rmdirSync(flashSwapDir);
            }
        }

        console.log(`Generated flash swap callbacks on ${chain}`);
    }

    const composerTestImport = "./test/shared/composers/ComposerPlugin.sol";
    fs.writeFileSync(composerTestImport, composerTestImports(chainsUsed));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
