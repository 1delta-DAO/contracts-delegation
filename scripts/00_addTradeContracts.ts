
import { ethers } from "hardhat";
import {
    AaveFlashModule__factory,
    BalancerFlashModule__factory,
    ConfigModule__factory,
    DeltaBrokerProxy__factory,
    DeltaFlashAggregator__factory,
    LensModule__factory,
    ManagementModule__factory,
} from "../types";
import { aaveAddresses, aaveBrokerAddresses, uniswapAddresses } from "../deploy/polygon_addresses"
import { validateAddresses } from "../utils/types";
import { parseUnits } from "ethers/lib/utils";
import { getContractSelectors, ModuleConfigAction } from "../test-ts/libraries/diamond";

const usedMaxFeePerGas = parseUnits('800', 9)
const usedMaxPriorityFeePerGas = parseUnits('40', 9)

const opts = {
    maxFeePerGas: usedMaxFeePerGas,
    maxPriorityFeePerGas: usedMaxPriorityFeePerGas
}

const addresses = aaveBrokerAddresses as any
const uniAddresses = uniswapAddresses as any

async function main() {


    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    const proxyAddress = addresses.BrokerProxy[chainId]
    const minimalRouter = addresses.minimalRouter[chainId]
    const uniswapFactory = uniAddresses.factory[chainId]
    const aavePool = (aaveAddresses as any).v3pool[chainId]

    validateAddresses([proxyAddress, minimalRouter, uniswapFactory, aavePool])

    console.log("Operate on", chainId, "by", operator.address)

    // deploy ConfigModule
    const broker = await new ConfigModule__factory(operator).attach(proxyAddress)

    const flashBroker = await new DeltaFlashAggregator__factory(operator).deploy(opts)
    await flashBroker.deployed()
    console.log("flashBroker deployed")

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


    // const balancerFlashModule = await new BalancerFlashModule__factory(operator).deploy(aavePool, balancerV2Vault[chainId])
    // await balancerFlashModule.deployed()
    // console.log("balancerFlashModule deployed")

    // const aaveFlashModule = await new AaveFlashModule__factory(operator).deploy(aavePool)
    // await aaveFlashModule.deployed()
    // console.log("aaveFlashModule deployed")

    // const lensModule = await new LensModule__factory(operator).deploy(opts)
    // await lensModule.deployed()
    // console.log("lens deployed")
    console.log("FlashBroker", flashBroker.address)
    // console.log("BrokerModuleBalancer", balancerFlashModule.address)
    // console.log("BrokerModulAave", aaveFlashModule.address)
    // console.log("UniswapV3SwapCallbackModule", callback.address)
    // console.log("MoneyMarketModule", moneyMarkets.address)
    // console.log("MarginTraderModule", marginTrading.address)
    // console.log("Sweeper", sweeper.address)

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
        flashBroker
        // sweeper,
        // marginTrading,
        // moneyMarkets,
        // callback,
        // lensModule,
        // management
    ]

    for (const module of modules) {
        cut.push({
            moduleAddress: module.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getContractSelectors(module)
        })
    }

    console.log("Cut:", cut)
    console.log("Attempt module adjustment - estimate gas")
    await broker.estimateGas.configureModules(cut)
    console.log("Estimate successful - configure!")
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


    // Operate on 137 by 0x999999833d965c275A2C102a4Ebf222ca938546f
    // callback deployed
    // margin trading deployed
    // money markets deployed
    // sweeper deployed
    // management deployed
    // balancerFlashModule deployed
    // aaveFlashModule deployed
    // BrokerModuleBalancer 0x3750F9458F2D7EeE37A4CDBDBf0fF96Bdca3AEB0
    // BrokerModulAave 0x92EAf17783Dd744E931061dB02592550569ec5f6
    // UniswapV3SwapCallbackModule 0x0dEE813588A06dD8f6bE14b11e8Bbb9fA8b4c618
    // MoneyMarketModule 0x554E97c885F92F091b08c03AfB24eEBdf8a720f7
    // MarginTraderModule 0x8AD54D6aF1cE5f5EE075118d0aFBE8b9800eE6Eb
    // Sweeper 0xc08BFef7E778f3519D79E96780b77066F5d4FCC0
    // Management 0xD3Bc8DCED6813e7E77b6380E534Da23Ff262AcD0
