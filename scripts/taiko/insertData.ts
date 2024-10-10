
import { ethers } from "hardhat";
import {
    TaikoManagementModule__factory,
} from "../../types";
import { addHanaTokens, addMeridianTokens, addTakoTakoTokens } from "./lenders/addLenderData";
import { execHanaApproves, execMeridianApproves, execTakoTakoApproves } from "./approvals/approveAddress";
import { ONE_DELTA_GEN2_ADDRESSES_TAIKO } from "./addresses/oneDeltaAddresses";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 167000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()
 
    const oneDeltaManagement = await new TaikoManagementModule__factory(operator).attach(ONE_DELTA_GEN2_ADDRESSES_TAIKO.proxy)

    // add lender data
    // nonce = await addHanaTokens(oneDeltaManagement, nonce)
    // nonce = await addMeridianTokens(oneDeltaManagement, nonce)
    nonce = await addTakoTakoTokens(oneDeltaManagement, nonce)

    // approve targets
    // nonce = await execHanaApproves(oneDeltaManagement, nonce)
    // nonce = await execMeridianApproves(oneDeltaManagement, nonce)
    nonce = await execTakoTakoApproves(oneDeltaManagement, nonce)

    console.log("insert complete")

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
