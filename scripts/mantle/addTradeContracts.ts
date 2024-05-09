
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    DeltaFlashAggregatorMantle__factory,
    LendleFlashModule__factory,
} from "../../types";
import { validateAddresses } from "../../utils/types";
import { getContractSelectors, ModuleConfigAction } from "../../test-ts/libraries/diamond";
import { lendleBrokerAddresses } from "../../deploy/mantle_addresses";



const MANTLE_CONFIGS = {
    maxFeePerGas: 0.02 * 1e9,
    maxPriorityFeePerGas: 0.02 * 1e9
}

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    const proxyAddress = lendleBrokerAddresses.BrokerProxy[chainId]

    validateAddresses([proxyAddress])
    if (chainId !== 5000) throw new Error("wring chain")
    console.log("Operate on", chainId, "by", operator.address)

    // get ConfigModule
    const broker = await new ConfigModule__factory(operator).attach(proxyAddress)

    const lendleFlashModule = await new LendleFlashModule__factory(operator).attach(lendleBrokerAddresses.LendleFlashModule[chainId])

    console.log("lendleFlashModule:", lendleFlashModule.address)


    // const flashBroker = await new DeltaFlashAggregatorMantle__factory(operator).deploy()
    // await flashBroker.deployed()
    // console.log("flashBroker deployed")


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
    // console.log("FlashBroker", flashBroker.address)
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
        // flashBroker
        // flashBroker,
        lendleFlashModule
        // moneyMarkets,
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
