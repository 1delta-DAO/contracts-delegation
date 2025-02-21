
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    OneDeltaComposerBase__factory,
} from "../../types";
import { getGasConfig } from "../_utils/getGasConfig";
import { ModuleConfigAction, getContractSelectors } from "../_utils/diamond";
import { OneDeltaBase } from "./oneDeltaAddresses";
import { Chain } from "@1delta/asset-registry";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== Chain.BASE) throw new Error("invalid chainId")

    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    let config = await getGasConfig(operator, 10, true)

    // config.gasLimit = 10_000_000

    // deploy modules

    // composer
    const composer = await new OneDeltaComposerBase__factory(operator).deploy({ ...config, nonce: nonce++ })
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

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(OneDeltaBase.PRODUCTION.proxy)

    let tx = await oneDeltaModuleConfig.configureModules(cut, { ...config, nonce: nonce++ })
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
