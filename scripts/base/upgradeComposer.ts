
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    LensModule__factory,
    OneDeltaComposerBase__factory,
} from "../../types";
import { getContractSelectors, ModuleConfigAction } from "../_utils/diamond";
import { getGasConfig } from "../_utils/getGasConfig";
import { OneDeltaBase } from "./oneDeltaAddresses";
import { Chain } from "@1delta/asset-registry";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== Chain.BASE) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    const STAGE = OneDeltaBase.PRODUCTION
    const { proxy, composerImplementation } = STAGE

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()
    let config = await getGasConfig(operator, 10, true)
    // deploy modules
    const lens = await new LensModule__factory(operator).attach(proxy)

    const composerSelectors = await lens.moduleFunctionSelectors(composerImplementation)

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    // remove old
    cut.push({
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: composerSelectors
    })

    console.log("deploy new composer")
    // composer
    const composer = await new OneDeltaComposerBase__factory(operator).deploy({ ...config, nonce: nonce++ })
    await composer.deployed()


    console.log("modules deployed")


    const modules: any = []
    modules.push(composer)

    console.log("Having", modules.length, "additions")

    for (const module of modules) {
        cut.push({
            moduleAddress: module.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getContractSelectors(module)
        })
    }

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(proxy)

    let tx = await oneDeltaModuleConfig.configureModules(cut, { ...config, nonce: nonce++ })
    await tx.wait()
    console.log("upgrade completed")

    console.log("deployment complete")
    console.log("======== Addresses =======")
    console.log("composerImplementation:", composer.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
