
import { ethers } from "hardhat";
import { ONE_DELTA_ADDRESSES } from "../../deploy/mantle_addresses";
import { DeltaBrokerProxy__factory } from "../../types";
import { getStratumApproves } from "./approvals/approveAddress";
import { MANTLE_CONFIGS } from "./utils";

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 5000) throw new Error("invalid chainId")

    const calls = getStratumApproves()
    const proxyAddress = ONE_DELTA_ADDRESSES.BrokerProxy[chainId]

    let tx;
    // get management module
    const management = await new DeltaBrokerProxy__factory(operator).attach(proxyAddress)

    console.log("est. gas")
    await management.estimateGas.multicall(calls)
    console.log("success")
    console.log("Approve targetToApprove")
    tx = await management.multicall(calls, MANTLE_CONFIGS)
    await tx.wait()
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });