
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    OwnershipModule__factory,
} from "../../types";
import { ModuleConfigAction, getContractSelectors } from "../_utils/diamond";
import { OneDeltaPolygon } from "./addresses/oneDeltaAddresses";
import { getGasConfig } from "../_utils/getGasConfig";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 137) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    const STAGE = OneDeltaPolygon.STAGING
    const { proxy } = STAGE

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()
    const config = await getGasConfig(operator)
    // deploy modules

    // composer
    const ownership = await new OwnershipModule__factory(operator).deploy({ ...config, nonce: nonce++ })
    await ownership.deployed()


    console.log("ownership deployed")

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


    const modules: any = []
    modules.push(ownership)

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
    console.log("modules added")


    console.log("addition complete")
    console.log("======== Addresses =======")
    console.log("ownership:", ownership.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
