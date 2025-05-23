
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    OneDeltaComposerMantle__factory,
    LensModule__factory,
} from "../../types";
import { getMantleConfig } from "./utils";
import { OneDeltaManlte } from "./addresses/oneDeltaAddresses";
import { getContractSelectors, ModuleConfigAction } from "../_utils/diamond";


async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    const STAGE = OneDeltaManlte.STAGING
    const { proxy, composerImplementation } = STAGE
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy module
    // composer
    const newComposer = await new OneDeltaComposerMantle__factory(operator).deploy(getMantleConfig(nonce++))
    await newComposer.deployed()


    console.log("module deployed")

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    // get lens to fetch modules
    const lens = await new LensModule__factory(operator).attach(proxy)

    const composerSelectors = await lens.moduleFunctionSelectors(composerImplementation)

    // remove old
    cut.push({
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: composerSelectors
    })

    // add new
    cut.push({
        moduleAddress: newComposer.address,
        action: ModuleConfigAction.Add,
        functionSelectors: getContractSelectors(newComposer)
    })

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(proxy)

    let tx = await oneDeltaModuleConfig.configureModules(cut, getMantleConfig(nonce++))
    await tx.wait()
    console.log("modules added")

    console.log("upgrade complete")
    console.log("======== Addresses =======")
    console.log("new composer:", newComposer.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
