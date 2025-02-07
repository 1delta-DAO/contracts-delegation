
import { ethers } from "hardhat";
import {
    ConfigModule__factory,
    LensModule__factory,
    ManagementModule__factory,
} from "../../types";
import { getGasConfig } from "../_utils/getGasConfig";
import { ModuleConfigAction, getContractSelectors } from "../_utils/diamond";
import { OneDeltaArbitrum } from "./addresses/oneDeltaAddresses";


async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    const STAGE = OneDeltaArbitrum.PRODUCTION
    const { proxy, managementImplementation } = STAGE

    if (chainId !== 42161) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    // let nonce = await operator.getTransactionCount()
    const config = await getGasConfig(operator)

    // deploy module
    // composer
    const newManagement = await new ManagementModule__factory(operator).deploy(config)
    await newManagement.deployed()

    console.log("module deployed")

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    // get lens to fetch modules
    const lens = await new LensModule__factory(operator).attach(proxy)

    const composerSelectors = await lens.moduleFunctionSelectors(managementImplementation)

    // remove old
    cut.push({
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: composerSelectors
    })

    // add new
    cut.push({
        moduleAddress: newManagement.address,
        action: ModuleConfigAction.Add,
        functionSelectors: getContractSelectors(newManagement)
    })

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(proxy)

    let tx = await oneDeltaModuleConfig.configureModules(cut, config)
    await tx.wait()
    console.log("modules added")

    console.log("upgrade complete")
    console.log("======== Addresses =======")
    console.log("new management:", newManagement.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
