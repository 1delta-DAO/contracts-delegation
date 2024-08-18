
import { ethers } from "hardhat";
import {
    MantleManagementModule__factory,
} from "../../types";
import {  addLendleTokens } from "./lenders/addLenderData";
import {  execLendleApproves } from "./approvals/approveAddress";
import { ONE_DELTA_GEN2_ADDRESSES } from "./addresses/oneDeltaAddresses";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    const proxyAddress = ONE_DELTA_GEN2_ADDRESSES.proxy

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    const oneDeltaManagement = await new MantleManagementModule__factory(operator).attach(proxyAddress)

    // add lender data
    nonce = await addLendleTokens(oneDeltaManagement, nonce)

    // approve targets
    nonce = await execLendleApproves(oneDeltaManagement, nonce)

    console.log("insertion completed")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
