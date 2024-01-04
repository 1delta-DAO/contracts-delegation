
import { ethers } from "hardhat";
import { ConfigModule__factory, LensModule__factory } from "../types";
import { aaveBrokerAddresses } from "../deploy/polygon_addresses"
import { validateAddresses } from "../utils/types";
import { parseUnits } from "ethers/lib/utils";
import { ModuleConfigAction } from "../test-ts/libraries/diamond";

const usedMaxFeePerGas = parseUnits('800', 9)
const usedMaxPriorityFeePerGas = parseUnits('40', 9)

const opts = {
    maxFeePerGas: usedMaxFeePerGas,
    maxPriorityFeePerGas: usedMaxPriorityFeePerGas
}

const addresses: { [field: string]: { [chain: number]: string } } = aaveBrokerAddresses

async function main() {


    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    const proxyAddress = addresses.BrokerProxy[chainId]
    // const minimalRouter = addresses.minimalRouter[chainId]
    const marginTradingAddress = addresses.MarginTraderModule[chainId]
    const managementAddress = addresses.ManagementModule[chainId]
    const balancerFlashAddress = addresses.BrokerModuleBalancer[chainId]
    const aaveFlashModuleAddress = addresses.BrokerModuleAave[chainId]
    const sweeperAddress = addresses.Sweeper[chainId]
    validateAddresses([proxyAddress, balancerFlashAddress, aaveFlashModuleAddress])

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
    console.log(marginTradingAddress)
    const marginTradingSelectors = await lens.moduleFunctionSelectors(marginTradingAddress)
    // console.log(marginTradingSelectors)
    const managementSelectors = await lens.moduleFunctionSelectors(managementAddress)
    // const sweeperSelectors = await lens.moduleFunctionSelectors(sweeperAddress)
    const aaveFlashSelectors = await lens.moduleFunctionSelectors(aaveFlashModuleAddress)
    const balancerFlashSelectors = await lens.moduleFunctionSelectors(balancerFlashAddress)
    const moduleSelectors = [
        // callbackSelectors,
        marginTradingSelectors,
        // moneyMarketSelectors,
        // sweeperSelectors,
        // aaveFlashSelectors,
        // balancerFlashSelectors,
        // viewerSelectors,
        // managementSelectors
    ]

    for (const selector of moduleSelectors) {
        cut.push({
            moduleAddress: ethers.constants.AddressZero,
            action: ModuleConfigAction.Remove,
            functionSelectors: selector
        })
    }

    console.log("Cut:", cut)
    console.log("Attempt module adjustment - estimate gas")
    await broker.estimateGas.configureModules(cut)
    console.log("Estimate successful - configure!")
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