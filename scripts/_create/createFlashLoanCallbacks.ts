import {AAVE_V2_LENDERS, AAVE_V3_LENDERS} from "@1delta/lender-registry";
import {getAddress} from "ethers/lib/utils";
import * as fs from "fs";
import {templateAaveV2} from "./templates/flashLoan/aaveV2Callback";
import {templateAaveV3} from "./templates/flashLoan/aaveV3Callback";
import {templateFlashLoan} from "./templates/flashLoan/flashLoanCallbacks.ts";
import {templateMorphoBlue} from "./templates/flashLoan/morphoCallback";
import {templateBalancerV2} from "./templates/flashLoan/balancerV2Callback";
import {templateComposer} from "./templates/composer";
import {CREATE_CHAIN_IDS, getChainKey, toCamelCaseWithFirstUpper} from "./config";
import {templateUniversalFlashLoan} from "./templates/flashLoan/universalFlashLoan";
import {templateBalancerV2Trigger} from "./templates/flashLoan/balancerV2Trigger";
import {BALANCER_V2_FORKS, FLASH_LOAN_IDS} from "@1delta/dex-registry";
import {CANCUN_OR_HIGHER} from "./chain/evmVersion";
import {fetchLenderMetaFromDirAndInitialize} from "./utils";
import {aavePools, morphoPools} from "@1delta/data-sdk";
import {templateMoolah} from "./templates/flashLoan/moolahCallback";

/** constant for the head part */
function createConstant(pool: string, lender: string) {
    return `address private constant ${lender} = ${getAddress(pool)};\n`;
}

/** switch-case entry for flash loan that validates a caller */
function createCase(lender: string, lenderId: string) {
    return `case ${lenderId} { pool := ${lender} }\n`;
}

/** switch-case entry for flash loan that validates a caller */
function createCaseSolo(lender: string, lenderId: string) {
    return `
    switch and(UINT8_MASK, shr(88, firstWord))
            case ${lenderId} { 
            if xor(caller(), ${lender}) {
                        mstore(0, INVALID_CALLER)
                        revert(0, 0x4)
                    }  
            }
        default{
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }`;
}

/** switch-case entry for flash loan that validates a caller */
function createCaseTriggerBalancerV2(lender: string, lenderId: string) {
    return `case ${lenderId} {
                pool := ${lender}
            }\n`;
}

/** switch-case entry for flash loan that validates a caller */
function createCaseSoloTriggerBalancerV2(lender: string) {
    return `
             let pool := ${lender}
    `;
}

/** start of switch case clauses if we allow multiple flash loan sources */
const multiSwitchCaseHead = `
            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator parameter the caller of flashLoan
            let pool
            switch and(UINT8_MASK, shr(88, firstWord))
            `;
/** end of switch case clauses if we allow multiple flash loan sources */
const multiSwitchCaseEnd = `
                    // We revert on any other id
                    default {
                        mstore(0, INVALID_FLASH_LOAN)
                        revert(0, 0x4)
                    }
                    // revert if caller is not a whitelisted pool
                    if xor(caller(), pool) {
                        mstore(0, INVALID_CALLER)
                        revert(0, 0x4)
                    }    
                    `;

interface FlashLoanIdData {
    entityName: string;
    entityId: string;
    pool: string;
}

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
const FLASH_LOAN_LENDER_EXCLUSIONS = {
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
            // Aave V2 forks — primarily deployed on other chains (Avalanche / Optimism / Arbitrum).
            "GRANARY",
            "RADIANT_V2",
        ],
    } as Record<string, string[]>,
};

function isLenderExcluded(chainId: string, lenderName: string): boolean {
    if (FLASH_LOAN_LENDER_EXCLUSIONS.ALWAYS.includes(lenderName)) return true;
    const chainExclusions = FLASH_LOAN_LENDER_EXCLUSIONS.BY_CHAIN[chainId];
    return chainExclusions !== undefined && chainExclusions.includes(lenderName);
}

function splitIntoGroups(numbers: number[], splits = 4): number[][] {
    const n = numbers.length;
    const boundaries: number[] = [];
    for (let i = 1; i < splits - 1; i++) {
        const idx = Math.floor((i * n) / splits);
        boundaries.push(numbers[idx]);
    }

    const result: number[][] = Array(boundaries.length + 1)
        .fill(0)
        .map(() => []);
    let splitIdx = 0;
    for (const num of numbers) {
        while (splitIdx < boundaries.length && num > boundaries[splitIdx]) {
            splitIdx++;
        }
        result[splitIdx].push(num);
    }
    return result;
}

function generateSwitchCaseStructure(entities: FlashLoanIdData[]): string {
    const groups = splitIntoGroups(entities.map(({entityId}) => Number(entityId)));

    // Create map for quick entityName lookup
    const entityMap = new Map<string, string>();
    entities.forEach((entity) => {
        entityMap.set(entity.entityId, entity.entityName);
    });

    let result = "";

    // Generate case statements for each ID
    const generateCases = (idGroup: number[]): string => {
        const cases = idGroup
            .map((id) => {
                const entityName = entityMap.get(id.toString());
                return createCase(entityName!, id.toString());
            })
            .join("\n");
        return `
            switch poolId
                ${cases}
            `;
    };

    // Handle first group directly
    result += `
    switch lt(poolId, ${1 + groups[0][groups[0].length - 1]})
    case 1 {
        ${generateCases(groups[0])}
    }
    `;
    // Handle remaining groups in nested structure
    if (groups.length > 1) {
        result += `default {\n`;

        for (let i = 1; i < groups.length; i++) {
            const group = groups[i];
            const isLast = i === groups.length - 1;

            if (!isLast) {
                result += `
                switch lt(poolId, ${1 + group[group.length - 1]})
                case 1 {
                    ${generateCases(group)}
                }
                default {
                `;
            } else {
                // Last group doesn't need an lte check
                result += `
                ${generateCases(group)}
                `;
            }
        }

        // Close open blocks
        for (let i = 1; i < groups.length; i++) {
            result += `}\n`;
        }
        result += `
                    // catch unassigned pool / bad poolId
                    if iszero(pool) {
                        mstore(0, INVALID_FLASH_LOAN)
                        revert(0, 0x4)
                    }  
                    // match pool address
                    if xor(caller(), pool) {
                        mstore(0, INVALID_CALLER)
                        revert(0, 0x4)
                    }    
        `;
    } else {
        result += multiSwitchCaseEnd;
    }

    return result;
}

async function main() {
    await fetchLenderMetaFromDirAndInitialize();

    const chains = CREATE_CHAIN_IDS;

    for (let i = 0; i < chains.length; i++) {
        const chain = chains[i];
        const isCancun = CANCUN_OR_HIGHER.includes(chain);
        console.log(`Start: ${chain}`);
        const key = getChainKey(chain);

        /** Create  `FlashLoanIdData` for each entity */

        let lenderIdsAaveV2: FlashLoanIdData[] = [];
        let lenderIdsAaveV3: FlashLoanIdData[] = [];
        // aave
        Object.entries(aavePools()).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
                    if (AAVE_V2_LENDERS.includes(lender as any)) {
                        if (FLASH_LOAN_IDS[lender] !== undefined && !isLenderExcluded(chain, lender))
                            lenderIdsAaveV2.push({
                                entityName: lender,
                                entityId: FLASH_LOAN_IDS[lender].toString(),
                                pool: e.pool,
                            });
                    }
                    if (AAVE_V3_LENDERS.includes(lender as any)) {
                        if (FLASH_LOAN_IDS[lender] !== undefined && !isLenderExcluded(chain, lender))
                            lenderIdsAaveV3.push({
                                entityName: lender,
                                entityId: FLASH_LOAN_IDS[lender].toString(),
                                pool: e.pool,
                            });
                    }
                }
            });
        });

        let lenderIdsMorphoBlue: FlashLoanIdData[] = [];
        let lenderIdsLista: FlashLoanIdData[] = [];
        Object.entries(morphoPools()).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
                    if (lender === "LISTA_DAO")
                        lenderIdsLista.push({
                            entityName: lender,
                            entityId: FLASH_LOAN_IDS[lender].toString(),
                            pool: e,
                        });
                    else
                        lenderIdsMorphoBlue.push({
                            entityName: lender,
                            entityId: FLASH_LOAN_IDS[lender].toString(),
                            pool: e,
                        });
                }
            });
        });

        let poolIdsBalancerV2: FlashLoanIdData[] = [];
        Object.entries(BALANCER_V2_FORKS).forEach(([lender, maps]) => {
            Object.entries(maps.vault).forEach(([chains, e]) => {
                if (chains === chain) {
                    poolIdsBalancerV2.push({
                        entityName: lender,
                        entityId: FLASH_LOAN_IDS[lender].toString(),
                        pool: e,
                    });
                }
            });
        });

        /**
         * Create code snippets
         * `constantsData` for the head constants
         * `switchCaseContent` for the switch-case validation parts
         */

        /**
         * Aave V2
         */
        let constantsDataV2 = ``;
        let switchCaseContentV2 = ``;
        lenderIdsAaveV2 = lenderIdsAaveV2.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));

        if (lenderIdsAaveV2.length === 1) {
            const {pool, entityName, entityId} = lenderIdsAaveV2[0];
            constantsDataV2 += createConstant(pool, entityName);
            switchCaseContentV2 += createCaseSolo(entityName, entityId);
        } else {
            switchCaseContentV2 += multiSwitchCaseHead;
            lenderIdsAaveV2.forEach(({pool, entityName, entityId}) => {
                constantsDataV2 += createConstant(pool, entityName);
                switchCaseContentV2 += createCase(entityName, entityId);
            });
            switchCaseContentV2 += multiSwitchCaseEnd;
        }

        /**
         * Aave V3
         */
        let constantsDataV3 = ``;
        let switchCaseContentV3 = ``;
        lenderIdsAaveV3 = lenderIdsAaveV3.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));
        if (lenderIdsAaveV3.length === 1) {
            const {pool, entityName, entityId} = lenderIdsAaveV3[0];
            constantsDataV3 += createConstant(pool, entityName);
            switchCaseContentV3 += createCaseSolo(entityName, entityId);
        } else if (lenderIdsAaveV3.length <= 8) {
            // Flat switch-case is smaller bytecode than the nested tree for small lender sets.
            // Threshold 8 chosen empirically: at ~6-8 cases, flat switch + default revert still beats
            // the 3-level-nested `switch lt(poolId, x)` tree generated by `generateSwitchCaseStructure`.
            // Beyond ~8, the tree's binary-search-like partitioning begins to win on bytecode size.
            switchCaseContentV3 += multiSwitchCaseHead;
            lenderIdsAaveV3.forEach(({pool, entityName, entityId}) => {
                constantsDataV3 += createConstant(pool, entityName);
                switchCaseContentV3 += createCase(entityName, entityId);
            });
            switchCaseContentV3 += multiSwitchCaseEnd;
        } else {
            // create the constants for all
            lenderIdsAaveV3.forEach(({pool, entityName}) => {
                constantsDataV3 += createConstant(pool, entityName);
            });
            // now create the nested switch case
            switchCaseContentV3 += `
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator parameter the caller of flashLoan
            let pool
            let poolId := and(UINT8_MASK, shr(88, firstWord))
            ${generateSwitchCaseStructure(lenderIdsAaveV3)}
            `;
        }

        /**
         * Morpho B
         */
        let constantsDataMorpho = ``;
        let switchCaseContentMorpho = ``;
        lenderIdsMorphoBlue = lenderIdsMorphoBlue.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));
        if (lenderIdsMorphoBlue.length === 1) {
            const {pool, entityName, entityId} = lenderIdsMorphoBlue[0];
            constantsDataMorpho += createConstant(pool, entityName);
            switchCaseContentMorpho += createCaseSolo(entityName, entityId);
        } else {
            switchCaseContentMorpho += multiSwitchCaseHead;
            lenderIdsMorphoBlue.forEach(({pool, entityName, entityId}) => {
                constantsDataMorpho += createConstant(pool, entityName);
                switchCaseContentMorpho += createCase(entityName, entityId);
            });
            switchCaseContentMorpho += multiSwitchCaseEnd;
        }

        /**
         * Lista D
         */
        let constantsDataLista = ``;
        let switchCaseContentLista = ``;
        lenderIdsLista = lenderIdsLista.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));
        if (lenderIdsLista.length === 1) {
            const {pool, entityName, entityId} = lenderIdsLista[0];
            constantsDataLista += createConstant(pool, entityName);
            switchCaseContentLista += createCaseSolo(entityName, entityId);
        } else {
            switchCaseContentLista += multiSwitchCaseHead;
            lenderIdsLista.forEach(({pool, entityName, entityId}) => {
                constantsDataLista += createConstant(pool, entityName);
                switchCaseContentLista += createCase(entityName, entityId);
            });
            switchCaseContentLista += multiSwitchCaseEnd;
        }
        /**
         * Balancer V2
         */
        let constantsDataBalancerV2 = ``;
        let switchCaseContentBalancerV2 = ``;
        let switchCaseContentBalancerV2Trigger = ``;
        poolIdsBalancerV2 = poolIdsBalancerV2.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));
        if (poolIdsBalancerV2.length === 1) {
            const {pool, entityName, entityId} = poolIdsBalancerV2[0];
            constantsDataBalancerV2 += createConstant(pool, entityName);
            switchCaseContentBalancerV2 += createCaseSolo(entityName, entityId);
            switchCaseContentBalancerV2Trigger += createCaseSoloTriggerBalancerV2(entityName);
        } else {
            switchCaseContentBalancerV2 += multiSwitchCaseHead;
            switchCaseContentBalancerV2Trigger += `
                            let pool
                            // switch-case over poolId to ensure trusted target
                            switch and(UINT8_MASK, shr(104, slice))

                            `;
            poolIdsBalancerV2.forEach(({pool, entityName, entityId}) => {
                constantsDataBalancerV2 += createConstant(pool, entityName);
                switchCaseContentBalancerV2 += createCase(entityName, entityId);
                switchCaseContentBalancerV2Trigger += createCaseTriggerBalancerV2(entityName, entityId);
            });
            switchCaseContentBalancerV2 += multiSwitchCaseEnd;
            switchCaseContentBalancerV2Trigger += `default { revert (0,0 )}`;
        }

        /** Write files */

        const flashLoanCallbackDir = `./contracts/1delta/composer/chains/${key}/flashLoan/callbacks/`;
        fs.mkdirSync(flashLoanCallbackDir, {recursive: true});

        // Helper: either write the callback or delete any stale file when the lender set becomes
        // empty (e.g. all chain lenders were excluded in `FLASH_LOAN_LENDER_EXCLUSIONS`).
        const writeOrDeleteCallback = (fileName: string, shouldWrite: boolean, content: string) => {
            const filePath = flashLoanCallbackDir + fileName;
            if (shouldWrite) {
                fs.writeFileSync(filePath, content);
            } else if (fs.existsSync(filePath)) {
                fs.rmSync(filePath);
            }
        };

        writeOrDeleteCallback(
            "AaveV2Callback.sol",
            lenderIdsAaveV2.length > 0,
            templateAaveV2(constantsDataV2, switchCaseContentV2),
        );
        writeOrDeleteCallback(
            "AaveV3Callback.sol",
            lenderIdsAaveV3.length > 0,
            templateAaveV3(constantsDataV3, switchCaseContentV3),
        );
        writeOrDeleteCallback(
            "MorphoCallback.sol",
            lenderIdsMorphoBlue.length > 0,
            templateMorphoBlue(constantsDataMorpho, switchCaseContentMorpho),
        );
        writeOrDeleteCallback(
            "MoolahCallback.sol",
            lenderIdsLista.length > 0,
            templateMoolah(constantsDataLista, switchCaseContentLista),
        );
        writeOrDeleteCallback(
            "BalancerV2Callback.sol",
            poolIdsBalancerV2.length > 0,
            templateBalancerV2(constantsDataBalancerV2, switchCaseContentBalancerV2, isCancun),
        );

        const filePathFlashCallbacks = `./contracts/1delta/composer/chains/${key}/flashLoan/FlashLoanCallbacks.sol`;
        fs.writeFileSync(
            filePathFlashCallbacks,
            templateFlashLoan(
                lenderIdsAaveV2.length > 0,
                lenderIdsAaveV3.length > 0,
                lenderIdsMorphoBlue.length > 0,
                poolIdsBalancerV2.length > 0,
                lenderIdsLista.length > 0
            )
        );

        const filePathFlashLoans = `./contracts/1delta/composer/chains/${key}/flashLoan/UniversalFlashLoan.sol`;
        fs.writeFileSync(
            filePathFlashLoans,
            templateUniversalFlashLoan(
                lenderIdsMorphoBlue.length > 0,
                lenderIdsAaveV2.length > 0,
                lenderIdsAaveV3.length > 0,
                poolIdsBalancerV2.length > 0
            )
        );

        if (poolIdsBalancerV2.length > 0) {
            const filePathBalancerV2FlashLoanTrigger = `./contracts/1delta/composer/chains/${key}/flashLoan/BalancerV2.sol`;
            fs.writeFileSync(
                filePathBalancerV2FlashLoanTrigger,
                templateBalancerV2Trigger(constantsDataBalancerV2, switchCaseContentBalancerV2Trigger, isCancun)
            );
        }

        const filePathComposer = `./contracts/1delta/composer/chains/${key}/Composer.sol`;
        fs.writeFileSync(filePathComposer, templateComposer(toCamelCaseWithFirstUpper(key)));

        console.log(`Generated flash loan callbacks on ${chain}`);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
