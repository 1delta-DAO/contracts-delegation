
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    OneDeltaComposerPolygon__factory,
} from "../../types";
import { getPolygonConfig } from "./utils";
import { ModuleConfigAction, getContractSelectors } from "../_utils/diamond";
import { OneDeltaPolygon } from "./addresses/oneDeltaAddresses";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 137) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy modules

    // composer
    const composer = await new OneDeltaComposerPolygon__factory(operator).deploy(getPolygonConfig(nonce++))
    await composer.deployed()


    console.log("composer deployed")

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


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

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(OneDeltaPolygon.STAGING.proxy)

    let tx = await oneDeltaModuleConfig.configureModules(cut, getPolygonConfig(nonce++))
    await tx.wait()
    console.log("modules added")


    console.log("addition complete")
    console.log("======== Addresses =======")
    console.log("composer:", composer.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
