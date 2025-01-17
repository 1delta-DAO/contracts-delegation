
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    OneDeltaComposerPolygon__factory,
    LensModule__factory,
} from "../../types";
import { getPolygonConfig } from "./utils";
import { OneDeltaPolygon } from "./addresses/oneDeltaAddresses";
import { getContractSelectors, ModuleConfigAction } from "../_utils/diamond";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 137) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    const STAGE = OneDeltaPolygon.STAGING
    const { proxy, composerImplementation } = STAGE

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

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
    const composer = await new OneDeltaComposerPolygon__factory(operator).deploy(getPolygonConfig(nonce++))
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

    let tx = await oneDeltaModuleConfig.configureModules(cut, getPolygonConfig(nonce++))
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
