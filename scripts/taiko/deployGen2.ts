
import { ethers } from "hardhat";
import {
    DeltaBrokerProxyGen2__factory,
    ConfigModule__factory,
    TaikoManagementModule__factory,
    OneDeltaComposerTaiko__factory,
    LensModule__factory,
} from "../../types";
import { getTaikoConfig } from "./utils";
import { ModuleConfigAction, getContractSelectors } from "../../test-ts/libraries/diamond";
import { addHanaTokens, addMeridianTokens } from "./lenders/addLenderData";
import { execHanaApproves, execMeridianApproves } from "./approvals/approveAddress";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 167000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()
    // deploy module config
    const moduleConfig = await new ConfigModule__factory(operator).deploy(getTaikoConfig(nonce++))
    await moduleConfig.deployed()

    console.log("moduleConfig deployed")

    // deploy proxy
    const proxy = await new DeltaBrokerProxyGen2__factory(operator).deploy(
        operator.address,
        moduleConfig.address,
        getTaikoConfig(nonce++)
    )
    await proxy.deployed()

    console.log("proxy deployed")

    // deploy modules

    // management
    const management = await new TaikoManagementModule__factory(operator).deploy(getTaikoConfig(nonce++))
    await management.deployed()

    // composer
    const composer = await new OneDeltaComposerTaiko__factory(operator).deploy(getTaikoConfig(nonce++))
    await composer.deployed()

    // lens
    const lens = await new LensModule__factory(operator).deploy(getTaikoConfig(nonce++))
    await lens.deployed()

    console.log("modules deployed")

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


    const modules: any = []
    modules.push(management)
    modules.push(composer)
    modules.push(lens)

    console.log("Having", modules.length, "additions")

    for (const module of modules) {
        cut.push({
            moduleAddress: module.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getContractSelectors(module)
        })
    }

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(proxy.address)

    let tx = await oneDeltaModuleConfig.configureModules(cut, getTaikoConfig(nonce++))
    await tx.wait()
    console.log("modules added")
    const oneDeltaManagement = await new TaikoManagementModule__factory(operator).attach(proxy.address)

    // add lender data
    nonce = await addHanaTokens(oneDeltaManagement, nonce)
    nonce = await addMeridianTokens(oneDeltaManagement, nonce)

    // approve targets
    nonce = await execHanaApproves(oneDeltaManagement, nonce)
    nonce = await execMeridianApproves(oneDeltaManagement, nonce)

    console.log("deployment complete")
    console.log("======== Addresses =======")
    console.log("moduleConfig:", moduleConfig.address)
    console.log("proxy:", proxy.address)
    console.log("composer:", composer.address)
    console.log("lens:", lens.address)
    console.log("management:", management.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
