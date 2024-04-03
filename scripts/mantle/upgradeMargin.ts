
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    DeltaFlashAggregatorMantle__factory,
    LensModule__factory,
} from "../../types";
import { validateAddresses } from "../../utils/types";
import { parseUnits } from "ethers/lib/utils";
import { getContractSelectors, ModuleConfigAction } from "../../test-ts/libraries/diamond";
import { lendleBrokerAddresses } from "../../deploy/mantle_addresses";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

// options for deployment
const opts = {}

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    const proxyAddress = lendleBrokerAddresses.BrokerProxy[chainId]

    validateAddresses([proxyAddress])
    console.log("Operate on", chainId, "by", operator.address)

    // deploy ConfigModule
    const broker = await new ConfigModule__factory(operator).attach(proxyAddress)

    const removeCuts = await getRemoveCut(operator, proxyAddress)
    // add cuts
    const marginTradingAddress = lendleBrokerAddresses.MarginTraderModule[chainId]
    const addCuts = await getAddCuts(operator, marginTradingAddress)

    const cut = [
        ...removeCuts,
        ...addCuts
    ]

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


const getRemoveCut = async (operator: SignerWithAddress, proxyAddress: string) => {
    const marginTradingAddress = '0xb613181AfD1adbC2a775b30D8b9A802793848760' // lendleBrokerAddresses.MarginTraderModule[chainId]
    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    // get lens to fetch modules
    const lens = await new LensModule__factory(operator).attach(proxyAddress)
    console.log(marginTradingAddress)
    const marginTradingSelectors = await lens.moduleFunctionSelectors(marginTradingAddress)

    const moduleSelectors = [
        marginTradingSelectors,
    ]
    console.log("Having", moduleSelectors.length, "removals")
    for (const selector of moduleSelectors) {
        cut.push({
            moduleAddress: ethers.constants.AddressZero,
            action: ModuleConfigAction.Remove,
            functionSelectors: selector
        })
    }

    return cut
}



const getAddCuts = async (operator: SignerWithAddress, flashAggregatorAddress: string,) => {
    const flashBroker = await new DeltaFlashAggregatorMantle__factory(operator).attach(flashAggregatorAddress)
    console.log("flashBroker picked")

    console.log("FlashBroker", flashBroker.address)

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


    const modules = [
        flashBroker,
    ]
    console.log("Having", modules.length, "additions")

    for (const module of modules) {
        cut.push({
            moduleAddress: module.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getContractSelectors(module)
        })
    }

    return cut
}