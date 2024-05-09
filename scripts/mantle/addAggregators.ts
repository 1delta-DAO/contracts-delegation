
import { ethers } from "hardhat";
import { lendleBrokerAddresses } from "../../deploy/mantle_addresses";
import { DeltaBrokerProxy__factory, ManagementModule__factory } from "../../types";
import { addressesTokensMantle } from "./lendleAddresses";

const underlyings = Object.values(addressesTokensMantle)

const aggregatorsTargets = [
    '0xD9F4e85489aDCD0bAF0Cd63b4231c6af58c26745', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5' // KYBER
]

const managementInterface = ManagementModule__factory.createInterface()

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 5000) throw new Error("invalid chainId")
    const proxyAddress = lendleBrokerAddresses.BrokerProxy[chainId]

    let tx;

    const approves = aggregatorsTargets.map((a) => {
        return managementInterface.encodeFunctionData("approveAddress", [underlyings, a])
    })

    const addAsValid = aggregatorsTargets.map((a) => {
        return managementInterface.encodeFunctionData("setValidTarget", [a, true])
    })

    const multicaller = await new DeltaBrokerProxy__factory(operator).attach(proxyAddress)

    console.log("est. gas")
    await multicaller.estimateGas.multicall([...approves, ...addAsValid])
    console.log("success")
    console.log("Enable Aggregators")
    tx = await multicaller.multicall([...approves, ...addAsValid])
    await tx.wait()
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });