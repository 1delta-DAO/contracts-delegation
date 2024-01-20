
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    DeltaBrokerProxy__factory,
    DeltaFlashAggregatorMantle__factory,
    DeltaFlashAggregator__factory,
    DeltaLendingInterfaceMantle__factory,
    LensModule__factory,
    ManagementModule__factory,
} from "../../types";
import { validateAddresses } from "../../utils/types";
import { parseUnits } from "ethers/lib/utils";
import { getContractSelectors, ModuleConfigAction } from "../../test-ts/libraries/diamond";
import { lendleBrokerAddresses } from "../../deploy/mantle_addresses";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";


const usedMaxFeePerGas = parseUnits('100', 9)
const usedMaxPriorityFeePerGas = parseUnits('10', 9)
const gasPrice = parseUnits('250', 9)

// options for deployment
const opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas,
    // gasPrice
    // gasLimit: 3500000
}

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

    const removeCuts = await getRemoveCuts(operator, proxyAddress)
    // add cuts
    const marginTradingAddress = lendleBrokerAddresses.MarginTraderModule[chainId]
    const lendingInterfacegAddress = lendleBrokerAddresses.LendingInterface[chainId]
    const addCuts = await getAddCuts(operator, marginTradingAddress, lendingInterfacegAddress)

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


const getRemoveCuts = async (operator: SignerWithAddress, proxyAddress: string) => {
    const chainId = 5000
    const marginTradingAddress = '0x97716A91e4e7Eb6f5E0449E23410D6E16B32e3C8' // lendleBrokerAddresses.MarginTraderModule[chainId]
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
    // const moneyMarketSelectors = await lens.moduleFunctionSelectors(moneyMarketAddress)
    // const managementSelectors = await lens.moduleFunctionSelectors(managementAddress)
    // const sweeperSelectors = await lens.moduleFunctionSelectors(sweeperAddress)
    // const aaveFlashSelectors = await lens.moduleFunctionSelectors(aaveFlashModuleAddress)
    // const balancerFlashSelectors = await lens.moduleFunctionSelectors(balancerFlashAddress)
    const moduleSelectors = [
        marginTradingSelectors,
        // moneyMarketSelectors,
        // sweeperSelectors,
        // aaveFlashSelectors,
        // balancerFlashSelectors,
        // managementSelectors
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



const getAddCuts = async (operator: SignerWithAddress, flashAggregatorAddress: string, lendingInterfaceAddress: string) => {
    const flashBroker = await new DeltaFlashAggregatorMantle__factory(operator).attach(flashAggregatorAddress)
    console.log("flashBroker picked")


    const moneyMarket = await new DeltaLendingInterfaceMantle__factory(operator).attach(lendingInterfaceAddress)
    console.log("moneyMarket picked")


    // const callback = await new UniswapV3SwapCallbackModule__factory(operator).deploy(uniswapFactory, aavePool, opts)
    // await callback.deployed()
    // console.log("callback deployed")

    // const marginTrading = await new AAVEMarginTraderModule__factory(operator).deploy(uniswapFactory, opts)
    // await marginTrading.deployed()
    // console.log("margin trading deployed")

    // const moneyMarkets = await new AAVEMoneyMarketModule__factory(operator).deploy(uniswapFactory, aavePool)
    // await moneyMarkets.deployed()
    // console.log("money markets deployed")

    // const sweeper = await new AAVESweeperModule__factory(operator).deploy(uniswapFactory, aavePool, opts)
    // await sweeper.deployed()
    // console.log("sweeper deployed")

    // const management = await new ManagementModule__factory(operator).deploy()
    // await management.deployed()
    // console.log("management deployed")

    // const lensModule = await new LensModule__factory(operator).deploy(opts)
    // await lensModule.deployed()
    // console.log("lens deployed")
    console.log("FlashBroker", flashBroker.address)
    console.log("LendingInterface", moneyMarket.address)
    // console.log("BrokerModuleBalancer", balancerFlashModule.address)
    // console.log("MoneyMarketModule", moneyMarkets.address)
    // console.log("MarginTraderModule", marginTrading.address)

    // console.log("Lens", lensModule.address)
    // console.log("Management", management.address)

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


    const modules = [
        // balancerFlashModule,
        // aaveFlashModule,
        // flashBroker
        // sweeper,
        flashBroker,
        moneyMarket,
        // moneyMarkets,
        // callback,
        // lensModule,
        // management
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