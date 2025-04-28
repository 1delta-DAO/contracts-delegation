import {AAVE_FORK_POOL_DATA, AAVE_V2_LENDERS, AAVE_V3_LENDERS, MORPHO_BLUE_POOL_DATA} from "@1delta/asset-registry";
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

/** constant for the head part */
function createConstant(pool: string, lender: string) {
    return `address private constant ${lender} = ${getAddress(pool)};\n`;
}

/** switch-case entry for flash loan that validates a caller */
function createCase(lender: string, lenderId: string) {
    return `case ${lenderId} {
                if xor(caller(), ${lender}) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }\n`;
}

/** switch-case entry for flash loan that validates a caller */
function createCaseSolo(lender: string) {
    return `    if xor(caller(), ${lender}) {
                    mstore(0, INVALID_CALLER)
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
            // the initiator paramter the caller of flashLoan
            switch and(UINT8_MASK, shr(88, firstWord))
            `;
/** end of switch case clauses if we allow multiple flash loan sources */
const multiSwitchCaseEnd = `
                      // We revert on any other id
                    default {
                        mstore(0, INVALID_FLASH_LOAN)
                        revert(0, 0x4)
                    }`;

interface FlashLoanIdData {
    entityName: string;
    entityId: string;
    pool: string;
}

function multiCaseSplitter(numbers: number[], splits = 4): number[] {
    // assuming the numbers are sorted (which is the case here)
    const n = numbers.length;
    const boundaries: number[] = [];
    for (let i = 1; i < splits - 1; i++) {
        const idx = Math.floor((i * n) / splits);
        boundaries.push(numbers[idx]);
    }
    return boundaries;
}

function splitByBoundaries(numbers: number[], splits: number[]): number[][] {
    const result: number[][] = Array(splits.length + 1)
        .fill(0)
        .map(() => []);
    let splitIdx = 0;
    for (const num of numbers) {
        while (splitIdx < splits.length && num > splits[splitIdx]) {
            splitIdx++;
        }
        result[splitIdx].push(num);
    }
    return result;
}

function generateSwitchCaseStructure(entities: {entityName: string; entityId: string}[]): string {
    const splits = multiCaseSplitter(entities.map(({entityId}) => Number(entityId)));

    const groups = splitByBoundaries(
        entities.map(({entityId}) => Number(entityId)),
        splits
    );

    if (groups.length === 0) return "";

    // Create map for quick entityName lookup
    const entityMap = new Map<string, string>();
    entities.forEach((entity) => {
        entityMap.set(entity.entityId, entity.entityName);
    });

    let result = "";

    // Generate case statements for each ID
    const generateCases = (idGroup: number[]): string => {
        return idGroup
            .map((id) => {
                const entityName = entityMap.get(id.toString());
                return createCase(entityName!, id.toString());
            })
            .join("\n");
    };

    // Handle first group directly
    result += `
    switch lt(poolId, ${1 + groups[0][groups[0].length - 1]})
    case 1 {
        switch poolId
        ${generateCases(groups[0])}
        // We revert on any other id
        default {
            mstore(0, INVALID_FLASH_LOAN)
            revert(0, 0x4)
        }
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
                    switch poolId
                    ${generateCases(group)}
                }
                default {
                `;
            } else {
                // Last group doesn't need an lte check
                result += `
                switch poolId
                ${generateCases(group)}
                `;
            }
        }

        // Close open blocks
        for (let i = 1; i < groups.length; i++) {
            result += `}\n`;
        }
    }

    return result;
}

async function main() {
    const chains = CREATE_CHAIN_IDS;

    for (let i = 0; i < chains.length; i++) {
        const chain = chains[i];
        console.log(`Start: ${chain}`);
        const key = getChainKey(chain);

        /** Create  `FlashLoanIdData` for each entity */

        let lenderIdsAaveV2: FlashLoanIdData[] = [];
        let lenderIdsAaveV3: FlashLoanIdData[] = [];
        // aave
        Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
                    if (AAVE_V2_LENDERS.includes(lender as any)) {
                        lenderIdsAaveV2.push({
                            entityName: lender,
                            entityId: FLASH_LOAN_IDS[lender].toString(),
                            pool: e.pool,
                        });
                    }
                    if (AAVE_V3_LENDERS.includes(lender as any)) {
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
        Object.entries(MORPHO_BLUE_POOL_DATA).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
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
            Object.entries(maps).forEach(([chains, e]) => {
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
            const {pool, entityName} = lenderIdsAaveV2[0];
            constantsDataV2 += createConstant(pool, entityName);
            switchCaseContentV2 += createCaseSolo(entityName);
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
            const {pool, entityName} = lenderIdsAaveV3[0];
            constantsDataV3 += createConstant(pool, entityName);
            switchCaseContentV3 += createCaseSolo(entityName);
        } else if (lenderIdsAaveV3.length <= 5) {
            switchCaseContentV3 += multiSwitchCaseHead;
            lenderIdsAaveV3.forEach(({pool, entityName, entityId}) => {
                constantsDataV3 += createConstant(pool, entityName);
                switchCaseContentV3 += createCase(entityName, entityId);
            });
            switchCaseContentV3 += multiSwitchCaseEnd;
        } else {
            const splits = multiCaseSplitter(lenderIdsAaveV3.map(({entityId}) => Number(entityId)));
            const groups = splitByBoundaries(
                lenderIdsAaveV3.map(({entityId}) => Number(entityId)),
                splits
            );
            // create the constants for all
            lenderIdsAaveV3.forEach(({pool, entityName}) => {
                constantsDataV3 += createConstant(pool, entityName);
            });
            // now create the nested switch case
            switchCaseContentV3 += `
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator paramter the caller of flashLoan
            let poolId := and(UINT8_MASK, shr(88, firstWord))
            `;

            // Generate the nested switch-case structure
            switchCaseContentV3 += generateSwitchCaseStructure(lenderIdsAaveV3);
        }
        /**
         * Morpho B
         */
        let constantsDataMorpho = ``;
        let switchCaseContentMorpho = ``;
        lenderIdsMorphoBlue = lenderIdsMorphoBlue.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));
        if (lenderIdsMorphoBlue.length === 1) {
            const {pool, entityName} = lenderIdsMorphoBlue[0];
            constantsDataMorpho += createConstant(pool, entityName);
            switchCaseContentMorpho += createCaseSolo(entityName);
        } else {
            switchCaseContentMorpho += multiSwitchCaseHead;
            lenderIdsMorphoBlue.forEach(({pool, entityName, entityId}) => {
                constantsDataMorpho += createConstant(pool, entityName);
                switchCaseContentMorpho += createCase(entityName, entityId);
            });
            switchCaseContentMorpho += multiSwitchCaseEnd;
        }
        /**
         * Balancer V2
         */
        let constantsDataBalancerV2 = ``;
        let switchCaseContentBalancerV2 = ``;
        let switchCaseContentBalancerV2Trigger = ``;
        poolIdsBalancerV2 = poolIdsBalancerV2.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));
        if (poolIdsBalancerV2.length === 1) {
            const {pool, entityName} = poolIdsBalancerV2[0];
            constantsDataBalancerV2 += createConstant(pool, entityName);
            switchCaseContentBalancerV2 += createCaseSolo(entityName);
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

        if (lenderIdsAaveV2.length > 0) {
            const filePathV2 = flashLoanCallbackDir + "AaveV2Callback.sol";
            fs.writeFileSync(filePathV2, templateAaveV2(constantsDataV2, switchCaseContentV2));
        }

        if (lenderIdsAaveV3.length > 0) {
            const filePathV3 = flashLoanCallbackDir + "AaveV3Callback.sol";
            fs.writeFileSync(filePathV3, templateAaveV3(constantsDataV3, switchCaseContentV3));
        }

        if (lenderIdsMorphoBlue.length > 0) {
            const filePathMorpho = flashLoanCallbackDir + "MorphoCallback.sol";
            fs.writeFileSync(filePathMorpho, templateMorphoBlue(constantsDataMorpho, switchCaseContentMorpho));
        }

        if (poolIdsBalancerV2.length > 0) {
            const filePathBalancerV2 = flashLoanCallbackDir + "BalancerV2Callback.sol";
            fs.writeFileSync(filePathBalancerV2, templateBalancerV2(constantsDataBalancerV2, switchCaseContentBalancerV2));
        }

        const filePathFlashCallbacks = `./contracts/1delta/composer/chains/${key}/flashLoan/FlashLoanCallbacks.sol`;
        fs.writeFileSync(
            filePathFlashCallbacks,
            templateFlashLoan(lenderIdsAaveV2.length > 0, lenderIdsAaveV3.length > 0, lenderIdsMorphoBlue.length > 0, poolIdsBalancerV2.length > 0)
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
                templateBalancerV2Trigger(constantsDataBalancerV2, switchCaseContentBalancerV2Trigger)
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
