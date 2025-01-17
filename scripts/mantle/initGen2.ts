
import { ethers } from "hardhat";
import {
    ManagementModule__factory,
} from "../../types";
import { OneDeltaManlte } from "./addresses/oneDeltaAddresses";
import { getLendleApproveDatas, getLendleDatas } from "./lenders/lendle";
import { getAureliusApproveDatas, getAureliusDatas } from "./lenders/aurelius";
import { getCompoundV3Approves } from "./lenders/compoundV3";
import { delay, getMantleConfig } from "./utils";
import { getInsertAggregators } from "./approvals/approveAll";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    const STAGE = OneDeltaManlte.PRODUCTION

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy modules

    // management
    const management = await new ManagementModule__factory(operator).attach(STAGE.proxy)

    const lendleDatas = getLendleDatas()
    const aureliusDatas = getAureliusDatas()

    console.log("add lender data")

    let tx = await management.batchAddGeneralLenderTokens(
        [
            ...lendleDatas,
            ...aureliusDatas,
        ],
        getMantleConfig(nonce++)
    )

    await tx.wait()

    // delay for 5s
    await delay(5000)

    console.log("lender data added")

    const lendleApproves = getLendleApproveDatas()
    const aureliusApproves = getAureliusApproveDatas()
    const compoundV3Approves = getCompoundV3Approves()

    tx = await management.batchApprove(
        [
            ...lendleApproves,
            ...aureliusApproves,
            ...compoundV3Approves,
        ],
        getMantleConfig(nonce++)
    )

    await tx.wait()

    // delay for 5s
    await delay(5000)

    console.log("apporves completed")

    const validTargets = getInsertAggregators()

    tx = await management.batchSetValidTarget(
        [
            ...validTargets,
        ],
        getMantleConfig(nonce++)
    )

    console.log("aggregators added")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
