
import { ethers } from "hardhat";
import { CometManagementModule__factory, CometMarginTraderModule__factory, CometMoneyMarketModule__factory, CometSweeperModule__factory, CometUniV3Callback__factory, ConfigModule__factory, DeltaBrokerProxy__factory, LensModule__factory, ManagementModule__factory, UniswapV3SwapCallbackModule__factory } from "../../types";
import { cometBrokerAddresses, uniswapAddresses } from "../../deploy/00_addresses"
import { validateAddresses } from "../../utils/types";
import { parseUnits } from "ethers/lib/utils";
import { getContractSelectors, getSelectors, ModuleConfigAction } from "../../test/diamond/libraries/diamond";



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

const addresses = cometBrokerAddresses as any
const uniAddresses = uniswapAddresses as any

async function main() {


    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    const proxyAddress = addresses.BrokerProxy[chainId]
    const minimalRouter = addresses.minimalRouter[chainId]
    const uniswapFactory = uniAddresses.factory[chainId]

    validateAddresses([proxyAddress, minimalRouter, uniswapFactory])

    console.log("Operate on", chainId, "by", operator.address)

    // deploy ConfigModule
    const broker = await new ConfigModule__factory(operator).attach(proxyAddress)

    // const callback = await new CometUniV3Callback__factory(operator).deploy(uniswapFactory, opts)
    // await callback.deployed()
    // console.log("callback deployed")

    // const marginTrading = await new CometMarginTraderModule__factory(operator).deploy(opts)
    // await marginTrading.deployed()
    // console.log("margin trading deployed")

    const moneyMarkets = await new CometMoneyMarketModule__factory(operator).deploy(uniswapFactory, opts)
    await moneyMarkets.deployed()
    console.log("money markets deployed")

    const sweeper = await new CometSweeperModule__factory(operator).deploy(uniswapFactory, opts)
    await sweeper.deployed()
    console.log("sweeper deployed")

    // const management = await new CometManagementModule__factory(operator).deploy()
    // await management.deployed()
    // console.log("management deployed")


    // const lensModule = await new LensModule__factory(operator).deploy(opts)
    // await lensModule.deployed()
    // console.log("lens deployed")

    // console.log("UniswapV3SwapCallbackModule", callback.address)
    // console.log("MoneyMarketModule", moneyMarkets.address)
    // console.log("MarginTraderModule", marginTrading.address)
    // console.log("Sweeper", sweeper.address)

    // console.log("Managemnt", management.address)
    // console.log("Lens", lensModule.address)

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


    const modules = [
        sweeper,
        // marginTrading,
        moneyMarkets,
        // callback,
        // management,
        // lensModule
    ]

    for (const module of modules) {
        cut.push({
            moduleAddress: module.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getContractSelectors(module)
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


    // Operate on 5 by 0x10E38dFfFCfdBaaf590D5A9958B01C9cfcF6A63B
    // UniswapV3SwapCallbackModule 0x52A1f48ee801Ed5119C9a361d855489C25F2dD9f
    // MoneyMarketModule 0xFfD3bd073cc9BAB3db28A60fDFB2831096342d6E
    // MarginTraderModule 0x0b814c915D4aBcd320bbcA84F3F49655eDE51553

