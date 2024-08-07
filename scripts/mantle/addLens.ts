
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    LensModule__factory,
} from "../../types";
import { getMantleConfig } from "./utils";
import { ModuleConfigAction, getContractSelectors } from "../../test-ts/libraries/diamond";
import { ONE_DELTA_GEN2_ADDRESSES } from "./addresses/oneDeltaAddresses";


async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    const proxyAddress = ONE_DELTA_GEN2_ADDRESSES.proxy
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy module
    // composer
    const lens = await new LensModule__factory(operator).deploy(getMantleConfig(nonce++))
    await lens.deployed()


    console.log("module deployed")

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    const modules: any = []
    modules.push(lens)

    console.log("Having", modules.length, "additions")

    for (const module of modules) {
        cut.push({
            moduleAddress: module.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getContractSelectors(module)
        })
    }

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(proxyAddress)

    let tx = await oneDeltaModuleConfig.configureModules(cut)
    await tx.wait()
    console.log("modules added")

    console.log("upgrade complete")
    console.log("======== Addresses =======")
    console.log("lens:", lens.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
