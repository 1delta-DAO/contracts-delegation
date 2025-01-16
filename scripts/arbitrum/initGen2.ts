
import { ethers } from "hardhat";
import {
    ManagementModule__factory,
} from "../../types";
import { OneDeltaArbitrum } from "./addresses/oneDeltaAddresses";
import { getAaveApproveDatas, getAaveDatas } from "./lenders/aaveV3";
import { getAvalonApproveDatas, getAvalonDatas, getAvalonPumpBTCApproveDatas, getAvalonPumpBTCDatas } from "./lenders/avalon";
import { getVenusApproveDatas, getVenusDatas, getVenusETHApproveDatas, getVenusETHDatas } from "./lenders/venus";
import { getYldrApproveDatas, getYldrDatas } from "./lenders/yldr";
import { getInsertAggregators } from "./aggregators/approveAll";
import { getCompoundV3Approves } from "./lenders/compoundV3";
import { getArbitrumConfig } from "../_utils/getGasConfig";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 42161) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    const STAGE = OneDeltaArbitrum.PRODUCTION
    const { proxy } = STAGE
    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy modules

    // management
    const management = await new ManagementModule__factory(operator).attach(proxy)

    const aaveDatas = getAaveDatas()
    const avalonDatas = getAvalonDatas()
    const avalonPBTCDatas = getAvalonPumpBTCDatas()
    const venusDatas = getVenusDatas()
    const venusETHDatas = getVenusETHDatas()
    const yldrDatas = getYldrDatas()

    console.log("add lender data")

    let tx = await management.batchAddGeneralLenderTokens(
        [
            ...aaveDatas,
            ...avalonDatas,
            ...avalonPBTCDatas,
            ...venusDatas,
            ...venusETHDatas,
            ...yldrDatas,
        ],
        getArbitrumConfig(nonce++)
    )

    await tx.wait()

    console.log("lender data added")

    const aaveApproves = getAaveApproveDatas()
    const avalonApproves = getAvalonApproveDatas()
    const avalonPBTCApproves = getAvalonPumpBTCApproveDatas()
    const venusApproves = getVenusApproveDatas()
    const venusETHApproves = getVenusETHApproveDatas()
    const yldrApproves = getYldrApproveDatas()
    const compoundV3Approves = getCompoundV3Approves()

    tx = await management.batchApprove(
        [
            ...aaveApproves,
            ...avalonApproves,
            ...avalonPBTCApproves,
            ...venusApproves,
            ...venusETHApproves,
            ...yldrApproves,
            ...compoundV3Approves,
        ],
        getArbitrumConfig(nonce++)
    )

    await tx.wait()

    console.log("apporves completed")

    const validTargets = getInsertAggregators()

    tx = await management.batchSetValidTarget(
        [

            ...validTargets,
        ],
        getArbitrumConfig(nonce++)
    )

    console.log("aggregators added")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
