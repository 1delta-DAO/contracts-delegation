
import { ethers } from "hardhat";
import { ONE_DELTA_ADDRESSES } from "../../deploy/mantle_addresses";
import { DeltaBrokerProxy__factory } from "../../types";
import { getAddAggregatorsMantle } from "./aggregators/addAggregators";
import { MANTLE_CONFIGS } from "./utils";

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 5000) throw new Error("invalid chainId")
    const proxyAddress = ONE_DELTA_ADDRESSES.BrokerProxy[chainId]

    const calls = getAddAggregatorsMantle()

    let tx;

    const multicaller = await new DeltaBrokerProxy__factory(operator).attach(proxyAddress)

    console.log("est. gas")
    await multicaller.estimateGas.multicall(calls)
    console.log("success")
    console.log("Enable Aggregators")
    tx = await multicaller.multicall(calls, MANTLE_CONFIGS)
    await tx.wait()
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });