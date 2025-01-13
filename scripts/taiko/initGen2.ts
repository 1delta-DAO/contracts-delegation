
import { ethers } from "hardhat";
import {
    ManagementModule__factory,
} from "../../types";
import { OneDeltaTaiko } from "./addresses/oneDeltaAddresses";
import { getMeridianApproveDatas, getMeridianDatas } from "./lenders/meridian";
import { getTakoTakoApproveDatas, getTakoTakoDatas } from "./lenders/takoTako";
import { getAvalonApproveDatas, getAvalonDatas } from "./lenders/avalon";
import { getHanaApproveDatas, getHanaDatas } from "./lenders/hana";
// import { getInsertAggregators } from "./aggregators/approveAll";
import { getTaikoConfig } from "./utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 167000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)


    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy modules

    // management
    const management = await new ManagementModule__factory(operator).attach(OneDeltaTaiko.STAGING.proxy)

    const HanaDatas = getHanaDatas()
    const AvalonDatas = getAvalonDatas()
    const TakoTakoDatas = getTakoTakoDatas()
    const MeridianDatas = getMeridianDatas()

    console.log("add lender data")

    let tx = await management.batchAddGeneralLenderTokens(
        [
            ...HanaDatas,
            ...AvalonDatas,
            ...TakoTakoDatas,
            ...MeridianDatas,
        ],
        getTaikoConfig(nonce++)
    )

    await tx.wait()

    console.log("lender data added")

    const HanaApproves = getHanaApproveDatas()
    const AvalonApproves = getAvalonApproveDatas()
    const TakoTakoApproves = getTakoTakoApproveDatas()
    const MeridianApproves = getMeridianApproveDatas()

    tx = await management.batchApprove(
        [
            ...HanaApproves,
            ...AvalonApproves,
            ...TakoTakoApproves,
            ...MeridianApproves,
        ],
        getTaikoConfig(nonce++)
    )

    await tx.wait()

    console.log("apporves completed")

    // const validTargets = getInsertAggregators()

    // tx = await management.batchSetSingleTarget(
    //     [

    //         ...validTargets,
    //     ],
    //     getTaikoConfig(nonce++)
    // )

    console.log("aggregators added")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
