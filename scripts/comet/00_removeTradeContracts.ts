
import { ethers } from "hardhat";
import { ConfigModule__factory, LensModule__factory } from "../../types";
import { cometBrokerAddresses } from "../../deploy/polygon_addresses"
import { validateAddresses } from "../../utils/types";
import { parseUnits } from "ethers/lib/utils";
import { ModuleConfigAction } from "../../test/diamond/libraries/diamond";

const usedMaxFeePerGas = parseUnits('100', 9)
const usedMaxPriorityFeePerGas = parseUnits('30', 9)

const opts = {
    maxFeePerGas: usedMaxFeePerGas,
    maxPriorityFeePerGas: usedMaxPriorityFeePerGas
}

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 137) throw new Error("Invalid chain")

    const proxyAddress = cometBrokerAddresses.BrokerProxy[chainId]
    const flashAggregatorAddress = cometBrokerAddresses.MarginTraderModule[chainId]
    const managementAddress = cometBrokerAddresses.ManagementModule[chainId]


    validateAddresses([proxyAddress, flashAggregatorAddress])

    console.log("Operate on", chainId, "by", operator.address)

    // get broker contract
    const broker = await new ConfigModule__factory(operator).attach(proxyAddress)

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    // get lens to fetch modules
    const lens = await new LensModule__factory(operator).attach(proxyAddress)

    const flashAggregatorSelectors = await lens.moduleFunctionSelectors(flashAggregatorAddress)
    const managementSelectors = await lens.moduleFunctionSelectors(managementAddress)

    const moduleSelectors = [
        // callbackSelectors,
        flashAggregatorSelectors,
        // managementSelectors,
    ]

    for (const selector of moduleSelectors) {
        cut.push({
            moduleAddress: ethers.constants.AddressZero,
            action: ModuleConfigAction.Remove,
            functionSelectors: selector
        })
    }

    console.log("Cut:", cut)
    console.log("Attempt module adjustment")
    const tx = await broker.configureModules(cut, opts)
    console.log('Module adjustment tx: ', tx.hash)
    const receipt = await tx.wait()
    if (!receipt.status) {
        throw Error(`Module adjustment failed: ${tx.hash}`)
    } else {
        console.log('Completed module adjustment')
        console.log("Upgrade done")
    }

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });