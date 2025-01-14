
import { ethers } from "hardhat";
import {
    ManagementModule__factory,
} from "../../types";
import { OneDeltaPolygon } from "./addresses/oneDeltaAddresses";
import { getAaveApproveDatas, getAaveDatas } from "./lenders/aaveV3";
import { getYldrApproveDatas, getYldrDatas } from "./lenders/yldr";
import { getInsertAggregators } from "./aggregators/approveAll";
import { getCompoundV3Approves } from "./lenders/compoundV3";
import { getPolygonConfig } from "./utils";
import { getAaveV2ApproveDatas, getAaveV2Datas } from "./lenders/aaveV2";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 137) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)


    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy modules

    // management
    const management = await new ManagementModule__factory(operator).attach(OneDeltaPolygon.STAGING.proxy)

    const aaveDatas = getAaveDatas()
    const aaveV2Datas = getAaveV2Datas()
    const yldrDatas = getYldrDatas()

    console.log("add lender data")

    let tx = await management.batchAddGeneralLenderTokens(
        [
            ...aaveDatas,
            ...aaveV2Datas,
            ...yldrDatas,
        ],
        getPolygonConfig(nonce++)
    )

    await tx.wait()

    console.log("lender data added")

    const aaveApproves = getAaveApproveDatas()
    const aaveV2Approves = getAaveV2ApproveDatas()
    const yldrApproves = getYldrApproveDatas()
    const compoundV3Approves = getCompoundV3Approves()

    tx = await management.batchApprove(
        [
            ...aaveApproves,
            ...aaveV2Approves,
            ...yldrApproves,
            ...compoundV3Approves,
        ],
        getPolygonConfig(nonce++)
    )

    await tx.wait()

    console.log("apporves completed")

    const validTargets = getInsertAggregators()

    tx = await management.batchSetValidTarget(
        [

            ...validTargets,
        ],
        getPolygonConfig(nonce++)
    )

    console.log("aggregators added")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
