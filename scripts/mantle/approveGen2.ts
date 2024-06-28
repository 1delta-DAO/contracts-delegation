
import { ethers } from "hardhat";
import {
    MantleManagementModule__factory,
} from "../../types";
import { execMUSDApproves } from "./approvals/approveAddress";
import { ONE_DELTA_GEN2_ADDRESSES } from "./addresses/oneDeltaAddresses";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()
   
    console.log("modules added")
    const oneDeltaManagement = await new MantleManagementModule__factory(operator).attach(ONE_DELTA_GEN2_ADDRESSES.proxy)

    nonce = await execMUSDApproves(oneDeltaManagement, nonce)

    console.log("deployment complete")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
