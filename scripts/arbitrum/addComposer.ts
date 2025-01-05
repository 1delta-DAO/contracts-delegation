
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    OneDeltaComposerMantle__factory,
} from "../../types";
import { getArbitrumConfig } from "./utils";
import { ModuleConfigAction, getContractSelectors } from "../_utils/diamond";
import { ONE_DELTA_GEN2_ADDRESSES } from "./addresses/oneDeltaAddresses";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy modules

    // composer
    const composer = await new OneDeltaComposerMantle__factory(operator).deploy(getArbitrumConfig(nonce++))
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

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(ONE_DELTA_GEN2_ADDRESSES.proxy)

    let tx = await oneDeltaModuleConfig.configureModules(cut)
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
