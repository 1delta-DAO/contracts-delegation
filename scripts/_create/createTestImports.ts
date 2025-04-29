

import { AAVE_FORK_POOL_DATA, AAVE_V2_LENDERS, AAVE_V3_LENDERS, MORPHO_BLUE_POOL_DATA } from "@1delta/asset-registry";
import { getAddress } from "ethers/lib/utils";
import * as fs from "fs";
import { templateAaveV2 } from "./templates/flashLoan/aaveV2Callback";
import { templateAaveV3 } from "./templates/flashLoan/aaveV3Callback";
import { templateFlashLoan } from "./templates/flashLoan/flashLoanCallbacks.ts";
import { templateMorphoBlue } from "./templates/flashLoan/morphoCallback";
import { templateBalancerV2 } from "./templates/flashLoan/balancerV2Callback";
import { templateComposer } from "./templates/composer";
import { CREATE_CHAIN_IDS, getChainKey, toCamelCaseWithFirstUpper } from "./config";
import { BALANCER_V2_FORKS } from "@1delta/dex-registry";


function createConstant(pool: string, lender: string) {
    return `address private constant ${lender} = ${getAddress(pool)};\n`
}

function createCase(lender: string, lenderId: string) {
    return `case ${lenderId} {
                if xor(caller(), ${lender}) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }\n`
}

interface LenderIdData {
    entityName: string
    entityId: string
    pool: string
}


async function main() {
    const chains = CREATE_CHAIN_IDS

    for (let i = 0; i < chains.length; i++) {
        const chain = chains[i]
        const key = getChainKey(chain)
        let lenderIdsAaveV2: LenderIdData[] = []
        let lenderIdsAaveV3: LenderIdData[] = []
        // aave
        Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender, maps], i) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
                    if (AAVE_V2_LENDERS.includes(lender as any)) {
                        lenderIdsAaveV2.push({ entityName: lender, entityId: "0", pool: e.pool })
                    }
                    if (AAVE_V3_LENDERS.includes(lender as any)) {
                        lenderIdsAaveV3.push({ entityName: lender, entityId: "0", pool: e.pool })
                    }
                }
            });
        });

        let lenderIdsMorphoBlue: LenderIdData[] = []
        Object.entries(MORPHO_BLUE_POOL_DATA).forEach(([lender, maps], i) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
                    lenderIdsMorphoBlue.push({ entityName: lender, entityId: "0", pool: e })

                }
            });
        });


        let poolIdsMBalancerV2: LenderIdData[] = []
        Object.entries(BALANCER_V2_FORKS).forEach(([lender, maps], i) => {
            Object.entries(maps).forEach(([chains, e]) => {
                if (chains === chain) {
                    poolIdsMBalancerV2.push({ entityName: lender, entityId: "0", pool: e })
                }
            });
        });


        /**
         * Aave V2
         */
        let constantsDataV2 = ``
        let switchCaseContentV2 = ``
        lenderIdsAaveV2 = lenderIdsAaveV2
            .sort((a, b) => a.entityName < b.entityName ? -1 : 1)
            .map((a, i) => ({ ...a, lenderId: String(i) }))
        // console.log("lenderIds", lenderIdsAaveV2)
        lenderIdsAaveV2.forEach(({ pool, entityName: lender }, i) => {
            constantsDataV2 += createConstant(pool, lender)
            switchCaseContentV2 += createCase(lender, String(i))
        })

        /**
         * Aave V3
         */
        let constantsDataV3 = ``
        let switchCaseContentV3 = ``
        lenderIdsAaveV3 = lenderIdsAaveV3
            .sort((a, b) => a.entityName < b.entityName ? -1 : 1)
            .map((a, i) => ({ ...a, lenderId: String(i) }))
        // console.log("lenderIds", lenderIdsAaveV3)
        lenderIdsAaveV3.forEach(({ pool, entityName: lender }, i) => {
            constantsDataV3 += createConstant(pool, lender)
            switchCaseContentV3 += createCase(lender, String(i))
        })

        /**
         * Morpho B
         */
        let constantsDataMorpho = ``
        let switchCaseContentMorpho = ``
        lenderIdsMorphoBlue = lenderIdsMorphoBlue
            .sort((a, b) => a.entityName < b.entityName ? -1 : 1)
            .map((a, i) => ({ ...a, lenderId: String(i) }))
        // console.log("lenderIds", lenderIdsMorphoBlue)
        lenderIdsMorphoBlue.forEach(({ pool, entityName: lender }, i) => {
            constantsDataMorpho += createConstant(pool, lender)
            switchCaseContentMorpho += createCase(lender, String(i))
        })

        /**
         * Balancer V2
         */
        let constantsDataBalancerV2 = ``
        let switchCaseContentBalancerV2 = ``
        poolIdsMBalancerV2 = poolIdsMBalancerV2
            .sort((a, b) => a.entityName < b.entityName ? -1 : 1)
            .map((a, i) => ({ ...a, lenderId: String(i) }))
        // console.log("lenderIds", poolIdsMBalancerV2)
        poolIdsMBalancerV2.forEach(({ pool, entityName: lender }, i) => {
            constantsDataBalancerV2 += createConstant(pool, lender)
            switchCaseContentBalancerV2 += createCase(lender, String(i))
        })



        const flashLoanCallbackDir = `./contracts/1delta/composer/chains/${key}/callbacks/flashLoan/`
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

        const filePathFlashCallbacks = `./contracts/1delta/composer/chains/${key}/callbacks/flashLoan/FlashLoanCallbacks.sol`
        fs.writeFileSync(filePathFlashCallbacks, templateFlashLoan(
            lenderIdsAaveV2.length > 0,
            lenderIdsAaveV3.length > 0,
            lenderIdsMorphoBlue.length > 0,
            poolIdsMBalancerV2.length > 0
        ));


        const filePathComposer = `./contracts/1delta/composer/chains/${key}/Composer.sol`
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

