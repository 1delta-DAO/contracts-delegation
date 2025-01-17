
import { ethers } from "hardhat";
import {
    DeltaBrokerProxyGen2__factory,
    ConfigModule__factory,
    ManagementModule__factory,
    LensModule__factory,
} from "../../types";
import { getArbitrumConfig } from "../_utils/getGasConfig";
import { ModuleConfigAction, getContractSelectors } from "../_utils/diamond";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 42161) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy module config
    const moduleConfig = await new ConfigModule__factory(operator).deploy(getArbitrumConfig(nonce++))
    await moduleConfig.deployed()

    console.log("moduleConfig deployed")

    // deploy proxy
    const proxy = await new DeltaBrokerProxyGen2__factory(operator).deploy(
        operator.address,
        moduleConfig.address,
        getArbitrumConfig(nonce++)
    )
    
    await proxy.deployed()

    console.log("proxy deployed")

    // deploy modules

    // management
    const management = await new ManagementModule__factory(operator).deploy(getArbitrumConfig(nonce++))
    await management.deployed()

    const lens = await new LensModule__factory(operator).deploy(getArbitrumConfig(nonce++))
    await lens.deployed()


    console.log("modules deployed")

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


    const modules: any = []
    modules.push(management)
    modules.push(lens)

    console.log("Having", modules.length, "additions")

    for (const module of modules) {
        cut.push({
            moduleAddress: module.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getContractSelectors(module)
        })
    }

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(proxy.address)

    let tx = await oneDeltaModuleConfig.configureModules(cut)
    await tx.wait()
    console.log("modules added")

    console.log("deployment complete")
    console.log("======== Addresses =======")
    console.log("moduleConfig:", moduleConfig.address)
    console.log("proxy:", proxy.address)
    console.log("management:", management.address)
    console.log("lens:", lens.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
