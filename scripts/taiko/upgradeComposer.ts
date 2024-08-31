
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    OneDeltaComposerTaiko__factory,
    LensModule__factory,
} from "../../types";
import { getTaikoConfig } from "./utils";
import { ModuleConfigAction, getContractSelectors } from "../../test-ts/libraries/diamond";
import { ONE_DELTA_GEN2_ADDRESSES_TAIKO } from "./addresses/oneDeltaAddresses";


async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    const proxyAddress = ONE_DELTA_GEN2_ADDRESSES_TAIKO.proxy
    const oldComposer = ONE_DELTA_GEN2_ADDRESSES_TAIKO.composerImplementation
    if (chainId !== 167000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy module
    // composer
    const newComposer = await new OneDeltaComposerTaiko__factory(operator).deploy(getTaikoConfig(nonce++))
    await newComposer.deployed()


    console.log("module deployed")

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    // get lens to fetch modules
    const lens = await new LensModule__factory(operator).attach(proxyAddress)

    const composerSelectors = await lens.moduleFunctionSelectors(oldComposer)

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

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(proxyAddress)

    let tx = await oneDeltaModuleConfig.configureModules(cut, getTaikoConfig(nonce++))
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
