
import { ethers } from "hardhat";
import { ConfigModule__factory, LensModule__factory, ManagementModule__factory, UniswapV3SwapCallbackModule__factory } from "../../types";
import { cometBrokerAddresses } from "../../deploy/00_addresses"
import { validateAddresses } from "../../utils/types";
import { parseUnits } from "ethers/lib/utils";
import { getContractSelectors, getSelectors, ModuleConfigAction } from "../../test/diamond/libraries/diamond";



const usedMaxFeePerGas = parseUnits('200', 9)
const usedMaxPriorityFeePerGas = parseUnits('20', 9)

const opts = {
    maxFeePerGas: usedMaxFeePerGas,
    maxPriorityFeePerGas: usedMaxPriorityFeePerGas
}

const addresses: { [field: string]: { [chain: number]: string } } = cometBrokerAddresses

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    const proxyAddress = addresses.BrokerProxy[chainId]
    const minimalRouter = addresses.minimalRouter[chainId]
    const callbackAddress = addresses.UniswapV3SwapCallbackModule[chainId]
    const marginTradingAddress = addresses.MarginTraderModule[chainId]
    const moneyMarketAddress = addresses.MoneyMarketModule[chainId]
    const managementAddress = addresses.ManagementModule[chainId]
    const sweeperAddress = addresses.Sweeper[chainId]


    validateAddresses([proxyAddress, minimalRouter, callbackAddress, marginTradingAddress, moneyMarketAddress, sweeperAddress])

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

    const callbackSelectors = await lens.moduleFunctionSelectors(callbackAddress)
    const marginTradingSelectors = await lens.moduleFunctionSelectors(marginTradingAddress)
    const managementSelectors = await lens.moduleFunctionSelectors(managementAddress)
    const moneyMarketSelectors = await lens.moduleFunctionSelectors(moneyMarketAddress)
    const sweeperSelectors = await lens.moduleFunctionSelectors(sweeperAddress)
    const moduleSelectors = [
        callbackSelectors,
        // marginTradingSelectors,
        // sweeperSelectors,
        // moneyMarketSelectors,
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
    const tx = await broker.configureModules(cut)
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