
import { ethers } from "hardhat";
import { CometFlashAggregatorPolygon__factory, ConfigModule__factory } from "../../types";
import { cometBrokerAddresses } from "../../deploy/polygon_addresses"
import { validateAddresses } from "../../utils/types";
import { parseUnits } from "ethers/lib/utils";
import { getContractSelectors, ModuleConfigAction } from "../../test-ts/libraries/diamond";


const usedMaxFeePerGas = parseUnits('800', 9)
const usedMaxPriorityFeePerGas = parseUnits('40', 9)

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

    validateAddresses([proxyAddress])

    console.log("Operate on", chainId, "by", operator.address)

    // deploy ConfigModule
    const broker = await new ConfigModule__factory(operator).attach(proxyAddress)

    const flashAggregator = await new CometFlashAggregatorPolygon__factory(operator).deploy(opts)
    await flashAggregator.deployed()
    console.log("money markets deployed")

    // const management = await new CometManagementModule__factory(operator).deploy()
    // await management.deployed()
    // console.log("management deployed")


    // const lensModule = await new LensModule__factory(operator).deploy(opts)
    // await lensModule.deployed()
    // console.log("lens deployed")

    console.log("FlashAggregator", flashAggregator.address)

    // console.log("Managemnt", management.address)
    // console.log("Lens", lensModule.address)

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


    const modules = [
        flashAggregator
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

