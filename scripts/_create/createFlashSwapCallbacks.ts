

import { Chain, CHAIN_INFO } from "@1delta/asset-registry";
import { getAddress } from "ethers/lib/utils";
import * as fs from "fs";
import { UNISWAP_V2_FORKS } from "./dex/uniV2";
import { templateUniV2 } from "./templates/flashSwap/uniV2Callback";
import { IZUMI_FORKS, UNISWAP_V3_FORKS } from "./dex/uniV3";
import { templateUniV3 } from "./templates/flashSwap/uniV3Callback";
import { uniq } from "lodash";
import { DODO_V2_DATA } from "./dex/dodoV2";
import { templateDodoV2 } from "./templates/flashSwap/dodoV2Callback";
import { DexProtocol } from "./dex/dexs";
import { templateSwapCallbacks } from "./templates/flashSwap/swapCallbacks";
import { UNISWAP_V4_FORKS } from "./dex/uniV4";
import { templateUniV4 } from "./templates/flashSwap/uniV4Callback";
import { BALANCER_V3_FORKS } from "./dex/balancerV3";
import { templateBalancerV3 } from "./templates/flashSwap/balancerV3Callback";
import { CREATE_CHAIN_IDS, getChainKey, sortForks } from "./config";
import { composerTestImports } from "./templates/test/composerImport";

/** simple address import */
function createConstant(pool: string, lender: string) {
    return `address private constant ${lender} = ${getAddress(pool)};\n`
}

/** constants imports for uni V2s and V3s */
function createffAddressConstant(pool: string, dexName: string, codeHash: string) {
    return `
            bytes32 private constant ${dexName}_FF_FACTORY = ${getAddress(pool).replace("0x", "0xff")}0000000000000000000000;
            bytes32 private constant ${dexName}_CODE_HASH = ${codeHash};
           `
}


/** createCase function for uni V2s and V3s */
function createCase(entityName: string, entityId: string) {
    return `case ${entityId} {
                ffFactoryAddress := ${entityName}_FF_FACTORY
                codeHash := ${entityName}_CODE_HASH

            }\n`
}

/** switch case for uni V4s and balancer V3 */
function createCaseUniV4BalV3(entityName: string, entityId: string) {
    return `case ${entityId} {
        if xor(caller(), ${entityName}) {
            mstore(0, INVALID_CALLER)
            revert(0, 0x4)
        }
    }\n`
}

/** selector head for uni V2s */
function createCaseSelectorV2(selector: string) {
    return `case ${selector} {
                switch and(UINT8_MASK, shr(88, outData))\n
    `
}

/** selector head for uni V3s */
function createCaseSelectorV3(selector: string) {
    return `case ${selector} {
                switch and(UINT8_MASK, shr(88, calldataload(172)))\n
    `
}

interface DexIdData {
    entityName: string
    entityId: string
    pool: string
    codeHash?: string
    callbackSelector?: string
}

async function main() {
    const chains = CREATE_CHAIN_IDS

    for (let i = 0; i < chains.length; i++) {
        const chain = chains[i]
        const key = getChainKey(chain)

        /** Create  `DexIdData` for each entity - these have additional info vs. flash loans */

        let dexIdsUniV2: DexIdData[] = []
        // uni V2
        Object.entries(UNISWAP_V2_FORKS).forEach(([dex, maps], i) => {
            Object.entries(maps.factories).forEach(([chains, address]) => {
                if (chains === chain) {
                    dexIdsUniV2.push({
                        entityName: dex,
                        entityId: maps.forkId,
                        pool: address,
                        codeHash: maps.codeHash[chain] ?? maps.codeHash.default,
                        callbackSelector: maps.callbackSelector,
                    })
                }
            });
        });


        let dexIdsUniV3: DexIdData[] = []
        // uni V3
        Object.entries(UNISWAP_V3_FORKS).forEach(([dex, maps], i) => {
            Object.entries(maps.factories).forEach(([chains, address]) => {
                if (chains === chain) {
                    dexIdsUniV3.push({
                        entityName: dex,
                        entityId: maps.forkId,
                        pool: address,
                        codeHash: maps.codeHash[chain] ?? maps.codeHash.default,
                        callbackSelector: maps.callbackSelector,
                    })
                }
            });
        });

        let dexIdsIzumi: DexIdData[] = []
        // izumi
        Object.entries(IZUMI_FORKS).forEach(([dex, maps], i) => {
            Object.entries(maps.factories).forEach(([chains, address]) => {
                if (chains === chain) {
                    dexIdsIzumi.push({
                        entityName: dex,
                        entityId: maps.forkId,
                        pool: address,
                        codeHash: maps.codeHash[chain] ?? maps.codeHash.default
                    })
                }
            });
        });

        let dexIdsUniV4: DexIdData[] = []
        // uni V4
        Object.entries(UNISWAP_V4_FORKS).forEach(([dex, maps], i) => {
            Object.entries(maps.pm).forEach(([chains, address]) => {
                if (chains === chain) {
                    dexIdsUniV4.push({
                        entityName: dex,
                        entityId: maps.forkId,
                        pool: address,
                    })
                }
            });
        });


        let dexIdsBalancerV3: DexIdData[] = []
        // uni V4
        Object.entries(BALANCER_V3_FORKS).forEach(([dex, maps], i) => {
            Object.entries(maps.vault).forEach(([chains, address]) => {
                if (chains === chain) {
                    dexIdsBalancerV3.push({
                        entityName: dex,
                        entityId: maps.forkId,
                        pool: address,
                    })
                }
            });
        });


        /** 
         * Create the imports similar to the flash loans
         * 2 parts, `constantsData` and `switchCaseContent`
         * based on the templates. 
         */

        /**
         * Uni V2
         */
        let constantsDataV2 = ``
        let switchCaseContentV2 = ``
        dexIdsUniV2 = dexIdsUniV2
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)
        const slectorsV2 = uniq(dexIdsUniV2.map(s => s.callbackSelector!))
        slectorsV2.forEach(sel => {
            const idsForSelector = dexIdsUniV2.filter(a => a.callbackSelector === sel)
            switchCaseContentV2 += createCaseSelectorV2(sel)
            idsForSelector.forEach(({ pool, entityName, codeHash, entityId }, i) => {
                constantsDataV2 += createffAddressConstant(pool, entityName, codeHash!)
                switchCaseContentV2 += createCase(entityName, entityId)
            })
            switchCaseContentV2 += `}\n`
        })

        /**
         * Uni V3
         */
        let constantsDataV3 = ``
        let switchCaseContentV3 = ``
        dexIdsUniV3 = dexIdsUniV3
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)
        const slectorsV3 = uniq(dexIdsUniV3.map(s => s.callbackSelector!))
        // console.log("entityIds", dexIdsUniV3)
        slectorsV3.forEach(sel => {
            const idsForSelector = dexIdsUniV3.filter(a => a.callbackSelector === sel)
            switchCaseContentV3 += createCaseSelectorV3(sel)
            idsForSelector.forEach(({ pool, entityName, codeHash, entityId }, i) => {
                constantsDataV3 += createffAddressConstant(pool, entityName, codeHash!)
                switchCaseContentV3 += createCase(entityName, entityId)
            })
            /** 
             * For uni V3, after each selector, we need to identifty the input amount 
             * Variants like Iumi do this differently, as such, we do it by selector
             */
            switchCaseContentV3 += `
                let _amount1 := calldataload(36)
                switch sgt(_amount1, 0)
                case 1 {
                    amountToPay := _amount1
                }
                default {
                    amountToPay := calldataload(4)
                }
            }\n`
        })

        /**
         * Uni V4
         */
        let constantsDataV4 = ``
        let switchCaseContentV4 = ``
        dexIdsUniV4 = dexIdsUniV4
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)
        // console.log("entityIds", dexIdsUniV4)
        dexIdsUniV4.forEach(({ pool, entityName, codeHash, entityId }, i) => {
            constantsDataV4 += createConstant(pool, entityName)
            switchCaseContentV4 += createCaseUniV4BalV3(entityName, entityId)

        })

        /**
         * Balncer V3
         */
        let constantsDataBalancerV3 = ``
        let switchCaseContentBalancerV3 = ``
        dexIdsBalancerV3 = dexIdsBalancerV3
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)
        // console.log("entityIds", dexIdsBalancerV3)
        dexIdsBalancerV3.forEach(({ pool, entityName, codeHash, entityId }, i) => {
            constantsDataBalancerV3 += createConstant(pool, entityName)
            switchCaseContentBalancerV3 += createCaseUniV4BalV3(entityName, entityId)

        })


        /**
         * Izumi
         */
        let constantsDataIzumi = ``
        let switchCaseContentIzumi = ``
        dexIdsIzumi = dexIdsIzumi
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)
        // console.log("entityIds", dexIdsIzumi)
        dexIdsIzumi.forEach(({ pool, entityName, codeHash, entityId }, i) => {
            constantsDataIzumi += createffAddressConstant(pool, entityName, codeHash!)
            switchCaseContentIzumi += createCase(entityName, entityId)
        })


        /** Write files */

        const flashSwapCallbackDir = `./contracts/1delta/modules/light/chains/${key}/callbacks/flashSwap/`
        fs.mkdirSync(flashSwapCallbackDir, { recursive: true });

        if (dexIdsUniV2.length > 0) {
            const filePathV2 = flashSwapCallbackDir + "UniV2Callback.sol";
            fs.writeFileSync(filePathV2, templateUniV2(constantsDataV2, switchCaseContentV2));
        }

        if (dexIdsUniV3.length > 0) {
            const filePathV3 = flashSwapCallbackDir + "UniV3Callback.sol";
            fs.writeFileSync(filePathV3, templateUniV3(
                constantsDataV3,
                switchCaseContentV3,
                constantsDataIzumi,
                switchCaseContentIzumi
            ));
        }

        const dodoData = DODO_V2_DATA[DexProtocol.DODO_V2]?.[chain]
        if (dodoData) {
            const filePathV3 = flashSwapCallbackDir + "DodoV2Callback.sol";
            fs.writeFileSync(filePathV3, templateDodoV2(
                dodoData.DVMFactory,
                dodoData.DSPFactory,
                dodoData.DPPFactory,
            ));
        }

        if (dexIdsUniV4.length > 0) {
            const filePathV4 = flashSwapCallbackDir + "UniV4Callback.sol";
            fs.writeFileSync(filePathV4, templateUniV4(
                constantsDataV4,
                switchCaseContentV4
            ));
        }


        if (dexIdsBalancerV3.length > 0) {
            const filePathBalancerV3 = flashSwapCallbackDir + "BalancerV3Callback.sol";
            fs.writeFileSync(filePathBalancerV3, templateBalancerV3(
                constantsDataBalancerV3,
                switchCaseContentBalancerV3
            ));
        }

        const filePathSwapCallbacks = flashSwapCallbackDir + "SwapCallbacks.sol";
        fs.writeFileSync(filePathSwapCallbacks, templateSwapCallbacks(
            dexIdsUniV4.length > 0,
            dexIdsUniV3.length > 0,
            dexIdsUniV2.length > 0,
            Boolean(dodoData),
            dexIdsBalancerV3.length > 0,
        ));


        console.log(`Generated flash swap callbacks on ${chain}`);
    }

    const composerTestImport = "./test/shared/composers/ComposerPlugin.sol";
    fs.writeFileSync(composerTestImport, composerTestImports(chains));

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

