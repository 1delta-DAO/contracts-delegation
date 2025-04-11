

import { AAVE_FORK_POOL_DATA, AAVE_V2_LENDERS, AAVE_V3_LENDERS, Chain, CHAIN_INFO } from "@1delta/asset-registry";
import { getAddress } from "ethers/lib/utils";
import * as fs from "fs";
import { templateAaveV2 } from "./templates/aaveV2Callback";
import { templateAaveV3 } from "./templates/aaveV3Callback";


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
    lender: string
    lenderId: string
    pool: string
}

const getChainKey = (chainId: string) => CHAIN_INFO[chainId].key!

async function main() {
    const chain = Chain.BASE
    const key = getChainKey(chain)
    let lenderIdsAaveV2: LenderIdData[] = []
    let lenderIdsAaveV3: LenderIdData[] = []
    let currentIdAaveV2 = 0
    let currentIdAaveV3 = 0
    // aave
    Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender, maps], i) => {
        Object.entries(maps).forEach(([chains, e]) => {
            if (chains === chain) {
                if (AAVE_V2_LENDERS.includes(lender as any)) {
                    lenderIdsAaveV2.push({ lender, lenderId: String(currentIdAaveV2), pool: e.pool })
                    currentIdAaveV2 += 1
                }
                if (AAVE_V3_LENDERS.includes(lender as any)) {
                    lenderIdsAaveV3.push({ lender, lenderId: String(currentIdAaveV3), pool: e.pool })
                    currentIdAaveV3 += 1
                }
            }
        });

    });

    let constantsDataV2 = ``
    let switchCaseContentV2 = ``
    lenderIdsAaveV2 = lenderIdsAaveV2.sort(a => a.lender.includes("AAVE") ? -1 : 1)
    console.log("lenderIds", lenderIdsAaveV2)
    lenderIdsAaveV2.forEach(({ pool, lender, lenderId }) => {
        constantsDataV2 += createConstant(pool, lender)
        switchCaseContentV2 += createCase(lender, lenderId)
    })


    let constantsDataV3 = ``
    let switchCaseContentV3 = ``
    lenderIdsAaveV3 = lenderIdsAaveV3.sort(a => a.lender.includes("AAVE") ? -1 : 1)
    console.log("lenderIds", lenderIdsAaveV3)
    lenderIdsAaveV3.forEach(({ pool, lender, lenderId }) => {
        constantsDataV3 += createConstant(pool, lender)
        switchCaseContentV3 += createCase(lender, lenderId)
    })


    const filePathV2 = `./contracts/1delta/BamBanV2.sol`;
    fs.writeFileSync(filePathV2, templateAaveV2(constantsDataV2, switchCaseContentV2));


    const filePathV3 = `./contracts/1delta/BamBanV3.sol`;
    fs.writeFileSync(filePathV3, templateAaveV3(constantsDataV3, switchCaseContentV3));

    console.log(`Generated BamBan.sol with library constants`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
