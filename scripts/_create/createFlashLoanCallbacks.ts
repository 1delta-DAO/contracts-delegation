

import { AAVE_FORK_POOL_DATA, AAVE_V2_LENDERS, AAVE_V3_LENDERS, MORPHO_BLUE_POOL_DATA } from "@1delta/asset-registry";
import { getAddress } from "ethers/lib/utils";
import * as fs from "fs";
import { templateAaveV2 } from "./templates/flashLoan/aaveV2Callback";
import { templateAaveV3 } from "./templates/flashLoan/aaveV3Callback";
import { templateFlahLoan } from "./templates/flashLoan/flashLoanCallbacks.ts";
import { BALANCER_V2_FORKS } from "./dex/balancerV2";
import { templateMorphoBlue } from "./templates/flashLoan/morphoCallback";
import { templateBalancerV2 } from "./templates/flashLoan/balancerV2Callback";
import { templateComposer } from "./templates/composer";
import { CREATE_CHAIN_IDS, getChainKey, toCamelCaseWithFirstUpper } from "./config";
import { FLASH_LOAN_IDS } from "./flashLoan/flashLoanIds";

/** constant for the head part */
function createConstant(pool: string, lender: string) {
    return `address private constant ${lender} = ${getAddress(pool)};\n`
}

/** switch-case entry for flash loan that validates a caller */
function createCase(lender: string, lenderId: string) {
    return `case ${lenderId} {
                if xor(caller(), ${lender}) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }\n`
}

interface FlashLoanIdData {
    entityName: string
    entityId: string
    pool: string
}


async function main() {
    const chains = CREATE_CHAIN_IDS

    for (let i = 0; i < chains.length; i++) {
        const chain = chains[i]
        const key = getChainKey(chain)

        /** Create  `FlashLoanIdData` for each entity */

        let lenderIdsAaveV2: FlashLoanIdData[] = []
        let lenderIdsAaveV3: FlashLoanIdData[] = []
        // aave
        Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
                    if (AAVE_V2_LENDERS.includes(lender as any)) {
                        lenderIdsAaveV2.push({
                            entityName: lender,
                            entityId: FLASH_LOAN_IDS[lender].toString(),
                            pool: e.pool
                        })
                    }
                    if (AAVE_V3_LENDERS.includes(lender as any)) {
                        lenderIdsAaveV3.push({
                            entityName: lender,
                            entityId: FLASH_LOAN_IDS[lender].toString(),
                            pool: e.pool
                        })
                    }
                }
            });
        });

        let lenderIdsMorphoBlue: FlashLoanIdData[] = []
        Object.entries(MORPHO_BLUE_POOL_DATA).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
                    lenderIdsMorphoBlue.push({
                        entityName: lender,
                        entityId: FLASH_LOAN_IDS[lender].toString(),
                        pool: e
                    })

                }
            });
        });


        let poolIdsMBalancerV2: FlashLoanIdData[] = []
        Object.entries(BALANCER_V2_FORKS).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
                    poolIdsMBalancerV2.push({
                        entityName: lender,
                        entityId: FLASH_LOAN_IDS[lender].toString(),
                        pool: e
                    })
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
        let constantsDataV2 = ``
        let switchCaseContentV2 = ``
        lenderIdsAaveV2 = lenderIdsAaveV2
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)
        lenderIdsAaveV2.forEach(({ pool, entityName, entityId }) => {
            constantsDataV2 += createConstant(pool, entityName)
            switchCaseContentV2 += createCase(entityName, entityId)
        })

        /**
         * Aave V3
         */
        let constantsDataV3 = ``
        let switchCaseContentV3 = ``
        lenderIdsAaveV3 = lenderIdsAaveV3
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)
        lenderIdsAaveV3.forEach(({ pool, entityName, entityId }) => {
            constantsDataV3 += createConstant(pool, entityName)
            switchCaseContentV3 += createCase(entityName, entityId)
        })

        /**
         * Morpho B
         */
        let constantsDataMorpho = ``
        let switchCaseContentMorpho = ``
        lenderIdsMorphoBlue = lenderIdsMorphoBlue
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)
        lenderIdsMorphoBlue.forEach(({ pool, entityName, entityId }) => {
            constantsDataMorpho += createConstant(pool, entityName)
            switchCaseContentMorpho += createCase(entityName, entityId)
        })

        /**
         * Balancer V2
         */
        let constantsDataBalancerV2 = ``
        let switchCaseContentBalancerV2 = ``
        poolIdsMBalancerV2 = poolIdsMBalancerV2
            .sort((a, b) => Number(a.entityId) < Number(b.entityId) ? -1 : 1)
        poolIdsMBalancerV2.forEach(({ pool, entityName, entityId }) => {
            constantsDataBalancerV2 += createConstant(pool, entityName)
            switchCaseContentBalancerV2 += createCase(entityName, entityId)
        })

        /** Write files */

        const flashLoanCallbackDir = `./contracts/1delta/modules/light/chains/${key}/callbacks/flashLoan/`
        fs.mkdirSync(flashLoanCallbackDir, { recursive: true });

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

        if (poolIdsMBalancerV2.length > 0) {
            const filePathBalancerV2 = flashLoanCallbackDir + "BalancerV2Callback.sol";
            fs.writeFileSync(filePathBalancerV2, templateBalancerV2(constantsDataBalancerV2, switchCaseContentBalancerV2));
        }

        const filePathFlashCallbacks = `./contracts/1delta/modules/light/chains/${key}/callbacks/flashLoan/FlashLoanCallbacks.sol`
        fs.writeFileSync(filePathFlashCallbacks, templateFlahLoan(
            lenderIdsAaveV2.length > 0,
            lenderIdsAaveV3.length > 0,
            lenderIdsMorphoBlue.length > 0,
            poolIdsMBalancerV2.length > 0
        ));


        const filePathComposer = `./contracts/1delta/modules/light/chains/${key}/Composer.sol`
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

