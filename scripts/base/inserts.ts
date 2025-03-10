
import { ethers } from "hardhat";
import {
    ManagementModule__factory,
} from "../../types";
import { getGasConfig } from "../_utils/getGasConfig";
import { OneDeltaBase } from "./oneDeltaAddresses";
import { getAaveForkApproves, getAaveForkDatas, getCompoundV3Approves } from "../_shared/lender/getDatas";
import { getAggregators } from "../_shared/aggregator/getDatas";
import { Chain } from "@1delta/asset-registry";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== Chain.BASE) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    const STAGE = OneDeltaBase.PRODUCTION

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy modules

    // management
    const management = await new ManagementModule__factory(operator).attach(STAGE.proxy)

    const aaveDatas = getAaveForkDatas(chainId)

    console.log("add lender data")


    let config = await getGasConfig(operator, 10, true)

    let tx = await management.batchAddGeneralLenderTokens(
        [
            ...aaveDatas,
        ],
        { ...config, nonce: nonce++ }
    )

    await tx.wait()

    console.log("lender data added")

    const aaveApproves = getAaveForkApproves(chainId)
    const compoundV3Approves = getCompoundV3Approves(chainId)

    tx = await management.batchApprove(
        [
            ...aaveApproves,
            ...compoundV3Approves,
        ],
        { ...config, nonce: nonce++ }
    )

    await tx.wait()

    console.log("apporves completed")

    const validTargets = getAggregators(chainId)

    tx = await management.batchSetValidTarget(
        [
            ...validTargets,
        ],
        { ...config, nonce: nonce++ }
    )

    await tx.wait()
    console.log("aggregators added")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
