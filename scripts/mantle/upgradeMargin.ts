
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    DeltaFlashAggregatorMantle__factory,
    DeltaLendingInterfaceMantle__factory,
    LensModule__factory,
    ManagementModule__factory,
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
        // ONE_DELTA_ADDRESSES.LendingInterface[chainId],
        // ONE_DELTA_ADDRESSES.ManagementModule[chainId],
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
    const marginTradingAddress = '0x73C6b2481EB21A89F533D8C494D963464b1181f3' // lendleBrokerAddresses.MarginTraderModule[chainId]
    // const moneyMarketAddress = '0xd3E55dd0BabB618f73240d283bBd38A551c48c7b' // lendleBrokerAddresses.LendingInterface[chainId]
    // const managementAddress = '0x6Bc6aCB905c1216B0119C87Bf9E178ce298310FA' // lendleBrokerAddresses.LendingInterface[chainId]
    // const initializerAddress = '0xA453ba397c61B0c292EA3959A858821145B2707F'

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    // get lens to fetch modules
    const lens = await new LensModule__factory(operator).attach(proxyAddress)

    const marginTradingSelectors = await lens.moduleFunctionSelectors(marginTradingAddress)
    // const moneyMarketSelectors = await lens.moduleFunctionSelectors(moneyMarketAddress)
    // const managementSelectors = await lens.moduleFunctionSelectors(managementAddress)
    // const initSelectors = await lens.moduleFunctionSelectors(initializerAddress)

    const moduleSelectors = [
        marginTradingSelectors,
        // moneyMarketSelectors,
        // managementSelectors,
        // initSelectors
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



const getAddCuts = async (operator: SignerWithAddress, flashAggregatorAddress: string, lendingInterface?: string, management?: string) => {

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

    if (management) {
        const managementModule = await new ManagementModule__factory(operator).attach(management)
        modules.push(managementModule)
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