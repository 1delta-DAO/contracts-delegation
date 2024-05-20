
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    DeltaFlashAggregatorMantle__factory,
    DeltaLendingInterfaceMantle__factory,
    LensModule__factory,
} from "../../types";
import { validateAddresses } from "../../utils/types";
import { getContractSelectors, ModuleConfigAction } from "../../test-ts/libraries/diamond";
import { ONE_DELTA_ADDRESSES } from "../../deploy/mantle_addresses";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { MANTLE_CONFIGS } from "./utils";

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    const proxyAddress = ONE_DELTA_ADDRESSES.BrokerProxy[chainId]

    validateAddresses([proxyAddress])
    console.log("Operate on", chainId, "by", operator.address)

    // deploy ConfigModule
    const broker = await new ConfigModule__factory(operator).attach(proxyAddress)

    const removeCuts = await getRemoveCut(operator, proxyAddress)

    // add cuts
    const addCuts = await getAddCuts(
        operator,
        ONE_DELTA_ADDRESSES.MarginTraderModule[chainId],
        ONE_DELTA_ADDRESSES.LendingInterface[chainId]
    )

    const cut = [
        ...removeCuts,
        ...addCuts
    ]

    console.log("Cut:", cut)
    console.log("Attempt module adjustment - estimate gas")
    await broker.estimateGas.configureModules(cut)
    console.log("Estimate successful - configure!")
    const tx = await broker.configureModules(cut, MANTLE_CONFIGS)
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
    const marginTradingAddress = '0xFA2cac1CacAaE741BCA20B5FAFd6E84A65Ad4C6D' // lendleBrokerAddresses.MarginTraderModule[chainId]
    const moneyMarketAddress = '0xFA2cac1CacAaE741BCA20B5FAFd6E84A65Ad4C6D' // lendleBrokerAddresses.LendingInterface[chainId]
    const initializerAddress =  ONE_DELTA_ADDRESSES.Init[5000]

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    // get lens to fetch modules
    const lens = await new LensModule__factory(operator).attach(proxyAddress)

    const marginTradingSelectors = await lens.moduleFunctionSelectors(marginTradingAddress)
    const moneyMarketSelectors = await lens.moduleFunctionSelectors(moneyMarketAddress)
    const initSelectors = await lens.moduleFunctionSelectors(initializerAddress)

    const moduleSelectors = [
        marginTradingSelectors,
        moneyMarketSelectors,
        initSelectors
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



const getAddCuts = async (operator: SignerWithAddress, flashAggregatorAddress: string, lendingInterface?: string) => {

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


    const modules: any = []
    if (flashAggregatorAddress) {
        const flashBroker = await new DeltaFlashAggregatorMantle__factory(operator).attach(flashAggregatorAddress)
        modules.push(flashBroker)
    }
    if (lendingInterface) {
        const moneyMarket = await new DeltaLendingInterfaceMantle__factory(operator).attach(lendingInterface)
        modules.push(moneyMarket)
    }

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