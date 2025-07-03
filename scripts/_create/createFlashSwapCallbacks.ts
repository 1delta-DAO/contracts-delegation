

import { getAddress } from "ethers/lib/utils";
import * as fs from "fs";
import { templateUniV2 } from "./templates/flashSwap/uniV2Callback";
import { templateUniV3 } from "./templates/flashSwap/uniV3Callback";
import { uniq } from "lodash";
import { templateDodoV2 } from "./templates/flashSwap/dodoV2Callback";
import { templateSwapCallbacks } from "./templates/flashSwap/swapCallbacks";
import { templateUniV4 } from "./templates/flashSwap/uniV4Callback";
import { templateBalancerV3 } from "./templates/flashSwap/balancerV3Callback";
import { CREATE_CHAIN_IDS, getChainKey } from "./config";
import { composerTestImports } from "./templates/test/composerImport";
import { customV2ValidationSnippets, customV3ValidationSnippets } from "./dex/customSnippets";

import { IZUMI_FORKS, UNISWAP_V2_FORKS, UNISWAP_V3_FORKS, DODO_V2_DATA, DexValidation, UNISWAP_V4_FORKS, BALANCER_V3_FORKS, DexProtocol, UniV3ForkType } from "@1delta/dex-registry"
import { DEX_TO_CHAINS_EXCLUSIONS } from "./dex/blacklists";

const SOLIDLY_V2_MIN_ID = 130
const SOLIDLY_V2_MIN_ID_LOW = 128

/** simple address import */
function createConstant(pool: string, lender: string) {
    return `address private constant ${lender} = ${getAddress(pool)};\n`
}

/** 
 * constants imports for uni V2s and V3s
 * respect overrdides that populate lower bytes and have no code hash 
 */
function createffAddressConstant(pool: string, dexName: string, codeHash: string, overrideConstants?: string, lowerFFs = false) {
    if (codeHash === DexValidation.OVERRIDE)
        return `
            ${overrideConstants ? overrideConstants : `bytes32 private constant ${dexName}_FACTORY = 0x000000000000000000000000${getAddress(pool).replace("0x", "")};`}
            `
    return `
            bytes32 private constant ${dexName}_FF_FACTORY = ${getAddress(pool).replace("0x", "0xff")}${lowerFFs ? "ffffffffffffffffffffff" : "0000000000000000000000"};
            bytes32 private constant ${dexName}_CODE_HASH = ${codeHash};
           `
}


/** createCase function for uni V3s for multiple entries */
function createCaseV3(entityName: string, entityId: string, override = false) {
    if (override) return `case ${entityId} {
    ffFactoryAddress := ${entityName}_FACTORY
    }\n`
    return `case ${entityId} {
                ffFactoryAddress := ${entityName}_FF_FACTORY
                codeHash := ${entityName}_CODE_HASH
            }\n`
}

/** createCase function for uni V3s for single entries */
function createCaseV3Solo(entityName: string, override = false) {
    if (override) return `
    ffFactoryAddress := ${entityName}_FACTORY
`
    return `
                ffFactoryAddress := ${entityName}_FF_FACTORY
                codeHash := ${entityName}_CODE_HASH
            `
}


/** createCase function for uni V2s with multiple entries */
function createCaseUniV2(entityName: string, entityId: string, override: boolean) {
    if (override) return `case ${entityId} {
        ffFactoryAddress := ${entityName}_FACTORY
    }\n`
    return `case ${entityId} {
                ffFactoryAddress := ${entityName}_FF_FACTORY
                codeHash := ${entityName}_CODE_HASH
            }\n`
}

/** createCase function for uni V2s single entry */
function createCaseUniV2Solo(entityName: string, override: boolean) {
    if (override) return `
        ffFactoryAddress := ${entityName}_FACTORY
    `
    return `
                ffFactoryAddress := ${entityName}_FF_FACTORY
                codeHash := ${entityName}_CODE_HASH
            `
}


/**
 * Create solidly switch-case content
 * Respect override case if any (to putuplate the address in lower bytes)
 * Iteratively execute if - else clauses with or resolves
 */
function createCaseSolidlyV2(dexDataArray: DexIdData[]) {
    // abbreviate single case
    if (dexDataArray.length === 1) {
        const { entityName, codeHash } = dexDataArray[0]
        // override produces only factory address lower padded
        return `
                ffFactoryAddress := ${entityName}${codeHash === DexValidation.OVERRIDE ? "" : `_FF`}_FACTORY
                ${codeHash === DexValidation.OVERRIDE ? "" : `codeHash := ${entityName}_CODE_HASH`}
               `
    }

    let entr = (entityName: string, entityId: string, rest: string, override: boolean) => override ? `
                    switch or(eq(forkId, ${entityId}), eq(forkId, ${Number(entityId) + 64}))
                    case 1 {
                        ffFactoryAddress := ${entityName}_FACTORY
                    }
                    default {
                        ${rest}
                    }`: `
                    switch or(eq(forkId, ${entityId}), eq(forkId, ${Number(entityId) + 64})) 
                    case 1 {
                        ffFactoryAddress := ${entityName}_FF_FACTORY
                        codeHash := ${entityName}_CODE_HASH
                    }
                    default {
                        ${rest}
                    }`

    const endData = dexDataArray[dexDataArray.length - 1]
    let data = endData.codeHash !== DexValidation.OVERRIDE ? `
        switch or(eq(forkId, ${endData.entityId}), eq(forkId, ${Number(endData.entityId) + 64})) 
        case 1 {
                ffFactoryAddress := ${endData.entityName}_FF_FACTORY
                codeHash := ${endData.entityName}_CODE_HASH
        } default { revert(0, 0) }
    ` : `
        switch or(eq(forkId, ${endData.entityId}), eq(forkId, ${Number(endData.entityId) + 64})) 
        case 1 {
            ffFactoryAddress := ${endData.entityName}_FACTORY
        } default { revert(0, 0) }
    `
    dexDataArray.reverse().slice(1).forEach(({ entityName, entityId, codeHash }, i) => {
        data = entr(entityName, entityId, data, codeHash === DexValidation.OVERRIDE)
    })

    return data

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

/** switch case for uni V4s and balancer V3 solo */
function createCaseUniV4BalV3Solo(entityName: string) {
    return `
        if xor(caller(), ${entityName}) {
            mstore(0, INVALID_CALLER)
            revert(0, 0x4)
        }
    `
}

/** selector head for uni V2s */
function createCaseSelectorV2(selector: string, isSolidlyOrSingle: boolean) {
    if (isSolidlyOrSingle) {
        return `case ${selector} {
                    forkId := and(UINT8_MASK, shr(88, outData))
        `
    }
    return `case ${selector} {
                forkId := and(UINT8_MASK, shr(88, outData))
                switch forkId\n
    `
}


/** selector head for uni V3s */
function createCaseSelectorV3(selector: string) {
    return `case ${selector} {
                switch and(UINT8_MASK, shr(88, calldataload(172)))\n
    `
}

/** selector head for uni V3s */
function createCaseSelectorV3Solo(selector: string) {
    return `case ${selector} {  `
}


/** selector head for uni V3s */
function createCaseSelectorIzi() {
    return `
        switch and(UINT8_MASK, shr(88, calldataload(172)))\n
    `
}

interface DexIdData {
    entityName: string
    entityId: string
    pool: string
    codeHash?: string
    callbackSelector?: string
    isAlgebra?: boolean
    impl?: string
}

async function main() {
    const chains = CREATE_CHAIN_IDS

    for (let i = 0; i < chains.length; i++) {
        let hasV2Override = false
        let v2OverrideData = ""
        const chain = chains[i]
        const key = getChainKey(chain)

        /** Create  `DexIdData` for each entity - these have additional info vs. flash loans */

        let dexIdsUniV2: DexIdData[] = []
        // uni V2
        Object.entries(UNISWAP_V2_FORKS).forEach(([dex, maps], i) => {
            Object.entries(maps.factories).forEach(([chains, address]) => {
                if (chains === chain) {
                    if (!DEX_TO_CHAINS_EXCLUSIONS[dex]?.includes(chain))
                        dexIdsUniV2.push({
                            entityName: dex,
                            entityId: maps.forkId,
                            pool: address,
                            codeHash: maps.codeHash[chain] ?? maps.codeHash.default,
                            callbackSelector: maps.callbackSelector,
                            impl: customV2ValidationSnippets[dex]?.[chain]?.constants
                        })
                }
            });
        });


        let hasV3Override = false
        let v3OverrideData = ""
        let dexIdsUniV3: DexIdData[] = []
        // uni V3
        Object.entries(UNISWAP_V3_FORKS).forEach(([dex, maps], i) => {
            Object.entries(maps.factories).forEach(([chains, address]) => {
                if (chains === chain) {
                    if (!DEX_TO_CHAINS_EXCLUSIONS[dex]?.includes(chain))
                        dexIdsUniV3.push({
                            entityName: dex,
                            entityId: maps.forkId,
                            pool: address,
                            codeHash: maps.codeHash[chain] ?? maps.codeHash.default,
                            callbackSelector: maps.callbackSelector,
                            impl: undefined,
                            isAlgebra: (maps.forkType[chain] ?? maps.forkType.default).startsWith("Algebra")
                        })
                }
            });
        });

        let dexIdsIzumi: DexIdData[] = []
        // izumi
        Object.entries(IZUMI_FORKS).forEach(([dex, maps], i) => {
            Object.entries(maps.factories).forEach(([chains, address]) => {
                if (chains === chain) {
                    if (!DEX_TO_CHAINS_EXCLUSIONS[dex]?.includes(chain))
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
                    if (!DEX_TO_CHAINS_EXCLUSIONS[dex]?.includes(chain))
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
                    if (!DEX_TO_CHAINS_EXCLUSIONS[dex]?.includes(chain))
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
        const slectorsV2 = uniq(dexIdsUniV2.filter(q => q.callbackSelector !== DexValidation.EXCLUDE).map(s => s.callbackSelector!))
        slectorsV2.forEach(sel => {
            const idsForSelector = dexIdsUniV2.filter(a => a.callbackSelector === sel)
            const overriddenIds = idsForSelector.filter(a => a.codeHash === DexValidation.OVERRIDE)

            if (
                idsForSelector.some(a => Number(a.entityId) < SOLIDLY_V2_MIN_ID_LOW) &&
                idsForSelector.some(a => Number(a.entityId) > SOLIDLY_V2_MIN_ID)
            ) throw new Error("IVALID: " + chain + " " + idsForSelector.map(a => a.entityName).join(","))
            const isSolidly = idsForSelector.every(a => Number(a.entityId) > SOLIDLY_V2_MIN_ID)

            // soldily and single validation overlap (where we do not initialize with the `switch` clause)
            switchCaseContentV2 += createCaseSelectorV2(sel, isSolidly || idsForSelector.length === 1)
            // solidily has a recusive creation of id validation
            if (isSolidly) {
                switchCaseContentV2 += createCaseSolidlyV2(idsForSelector)
            }
            // single case first, we use the abbreviated version that does not do a switch-case
            if (idsForSelector.length === 1) {
                const { pool, entityName, codeHash, impl } = idsForSelector[0]
                // add constants at the top of the file
                constantsDataV2 += createffAddressConstant(pool, entityName, codeHash!, impl)
                // for solidly, we already created the switch-case type check at the top
                if (!isSolidly) switchCaseContentV2 += createCaseUniV2Solo(entityName, codeHash === DexValidation.OVERRIDE)
            }
            // multiple cases
            else {
                idsForSelector.forEach(({ pool, entityName, codeHash, entityId, impl }, i) => {
                    // add constants at the top of the file
                    constantsDataV2 += createffAddressConstant(pool, entityName, codeHash!, impl)
                    // for solidly, we already created the switch-case type check at the top
                    if (!isSolidly) switchCaseContentV2 += createCaseUniV2(entityName, entityId, codeHash === DexValidation.OVERRIDE)
                })
                if (!isSolidly) switchCaseContentV2 += `default { revert(0, 0) }`
            }
            switchCaseContentV2 += `}\n`
            if (overriddenIds.length > 0) {
                if (overriddenIds.length > 1) throw new Error("2 overrides not supported")
                v2OverrideData = customV2ValidationSnippets[overriddenIds[0].entityName as any][chain as any]?.code
                // set fag to true for validation at the bottom
                hasV2Override = true
            }

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
            const overriddenIds = idsForSelector.filter(a => a.codeHash === DexValidation.OVERRIDE)

            // single case
            if (idsForSelector.length === 1) {
                switchCaseContentV3 += createCaseSelectorV3Solo(sel)
                const { pool, entityName, codeHash, impl, isAlgebra } = idsForSelector[0]
                constantsDataV3 += createffAddressConstant(pool, entityName, codeHash!, impl, isAlgebra)
                switchCaseContentV3 += createCaseV3Solo(entityName, codeHash === DexValidation.OVERRIDE)
            }
            // multi case
            else {
                switchCaseContentV3 += createCaseSelectorV3(sel)
                idsForSelector.forEach(({ pool, entityName, codeHash, entityId, impl, isAlgebra }, i) => {
                    constantsDataV3 += createffAddressConstant(pool, entityName, codeHash!, impl, isAlgebra)
                    switchCaseContentV3 += createCaseV3(entityName, entityId, codeHash === DexValidation.OVERRIDE)
                })
                // mutli case rejects invalid ids
                switchCaseContentV3 += `default { revert(0, 0) }`
            }

            if (overriddenIds.length > 0) {
                if (overriddenIds.length > 1) throw new Error("2 overrides not supported")
                console.log("test", overriddenIds[0].entityName, chain)
                v3OverrideData = customV3ValidationSnippets[overriddenIds[0].entityName as any][chain as any]
                // set fag to true for validation at the bottom
                hasV3Override = true
            }

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

        if (dexIdsUniV4.length === 1) {
            const { pool, entityName } = dexIdsUniV4[0]
            constantsDataV4 += createConstant(pool, entityName)
            switchCaseContentV4 += createCaseUniV4BalV3Solo(entityName)
        } else {
            switchCaseContentV4 += `switch poolId`
            dexIdsUniV4.forEach(({ pool, entityName, entityId }, i) => {
                constantsDataV4 += createConstant(pool, entityName)
                switchCaseContentV4 += createCaseUniV4BalV3(entityName, entityId)
            })

            // default to a fail state if id not known
            switchCaseContentV4 += `
                default {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }
            `
        }

        /**
         * Balancer V3
         */
        let constantsDataBalancerV3 = ``
        let switchCaseContentBalancerV3 = ``
        dexIdsBalancerV3 = dexIdsBalancerV3
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)

        if (dexIdsBalancerV3.length === 1) {
            const { pool, entityName } = dexIdsBalancerV3[0]
            constantsDataBalancerV3 += createConstant(pool, entityName)
            switchCaseContentBalancerV3 += createCaseUniV4BalV3Solo(entityName)
        } else {
            switchCaseContentBalancerV3 += `switch poolId`
            dexIdsBalancerV3.forEach(({ pool, entityName, entityId }, i) => {
                constantsDataBalancerV3 += createConstant(pool, entityName)
                switchCaseContentBalancerV3 += createCaseUniV4BalV3(entityName, entityId)
            })
            // default to a fail state if id not known
            switchCaseContentBalancerV3 += `
                default {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }
        `
        }

        /**
         * Izumi
         */
        let constantsDataIzumi = ``
        let switchCaseContentIzumi = ``
        dexIdsIzumi = dexIdsIzumi
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)

        // optional izumi
        if (dexIdsIzumi.length > 0) {

            // single case
            if (dexIdsIzumi.length === 1) {
                const { pool, entityName, codeHash } = dexIdsIzumi[0]
                constantsDataIzumi += createffAddressConstant(pool, entityName, codeHash!)
                switchCaseContentIzumi += createCaseV3Solo(entityName)
            } else {
                switchCaseContentIzumi += createCaseSelectorIzi()
                dexIdsIzumi.forEach(({ pool, entityName, codeHash, entityId }, i) => {
                    constantsDataIzumi += createffAddressConstant(pool, entityName, codeHash!)
                    switchCaseContentIzumi += createCaseV3(entityName, entityId)
                })
                // multi case defaults to revert for wrong id
                switchCaseContentIzumi += `default { revert(0, 0) }`
            }
        }

        /** Write files */

        const flashSwapCallbackDir = `./contracts/1delta/composer/chains/${key}/flashSwap/callbacks/`
        fs.mkdirSync(flashSwapCallbackDir, { recursive: true });

        if (dexIdsUniV2.length > 0) {
            const filePathV2 = flashSwapCallbackDir + "UniV2Callback.sol";
            fs.writeFileSync(filePathV2, templateUniV2(
                constantsDataV2,
                switchCaseContentV2,
                hasV2Override,
                v2OverrideData
            ));
        }

        if (dexIdsUniV3.length > 0) {
            const filePathV3 = flashSwapCallbackDir + "UniV3Callback.sol";
            fs.writeFileSync(filePathV3, templateUniV3(
                constantsDataV3,
                switchCaseContentV3,
                constantsDataIzumi,
                switchCaseContentIzumi,
                hasV3Override,
                v3OverrideData
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
                switchCaseContentV4,
                dexIdsUniV4.length > 1
            ));
        }


        if (dexIdsBalancerV3.length > 0) {
            const filePathBalancerV3 = flashSwapCallbackDir + "BalancerV3Callback.sol";
            fs.writeFileSync(filePathBalancerV3, templateBalancerV3(
                constantsDataBalancerV3,
                switchCaseContentBalancerV3,
                dexIdsBalancerV3.length > 1
            ));
        }

        const filePathSwapCallbacks = `./contracts/1delta/composer/chains/${key}/flashSwap/SwapCallbacks.sol`;
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

