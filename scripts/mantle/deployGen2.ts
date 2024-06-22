
import { ethers } from "hardhat";
import {
    DeltaBrokerProxyGen2__factory,
    ConfigModule__factory,
    MantleManagementModule__factory,
    OneDeltaComposerMantle__factory,
} from "../../types";
import { getMantleConfig } from "./utils";
import { ModuleConfigAction, getContractSelectors } from "../../test-ts/libraries/diamond";
import { addAureliusTokens, addLendleTokens, getAddAureliusTokens } from "./lenders/addLenderData";
import { execAureliusApproves, execLendleApproves, execStratumApproves } from "./approvals/approveAddress";

const aggregatorsTargets = [
    '0xD9F4e85489aDCD0bAF0Cd63b4231c6af58c26745', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5' // KYBER
]

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()
    // deploy module config
    const moduleConfig = await new ConfigModule__factory(operator).deploy(getMantleConfig(nonce++))
    await moduleConfig.deployed()

    console.log("moduleConfig deployed")

    // deploy proxy
    const proxy = await new DeltaBrokerProxyGen2__factory(operator).deploy(
        operator.address,
        moduleConfig.address,
        getMantleConfig(nonce++)
    )
    await proxy.deployed()

    console.log("proxy deployed")

    // deploy modules

    // management
    const management = await new MantleManagementModule__factory(operator).deploy(getMantleConfig(nonce++))
    await management.deployed()

    // composer
    const composer = await new OneDeltaComposerMantle__factory(operator).deploy(getMantleConfig(nonce++))
    await composer.deployed()


    console.log("modules deployed")

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []


    const modules: any = []
    modules.push(management)
    modules.push(composer)

    console.log("Having", modules.length, "additions")

    for (const module of modules) {
        cut.push({
            moduleAddress: module.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getContractSelectors(module)
        })
    }

    const oneDeltaModuleConfig = await new ConfigModule__factory(operator).attach(proxy.address)

    let tx = await oneDeltaModuleConfig.configureModules(cut)
    await tx.wait()
    console.log("modules added")
    const oneDeltaManagement = await new MantleManagementModule__factory(operator).attach(proxy.address)

    // add aggregators
    tx = await oneDeltaManagement.setValidTarget(aggregatorsTargets[0], aggregatorsTargets[0], true, getMantleConfig(nonce++))
    await tx.wait()
    tx = await oneDeltaManagement.setValidTarget(aggregatorsTargets[1], aggregatorsTargets[1], true, getMantleConfig(nonce++))
    await tx.wait()

    // add lender data
    nonce = await addLendleTokens(oneDeltaManagement, nonce)
    nonce = await addAureliusTokens(oneDeltaManagement, nonce)

    // approve targets
    nonce = await execAureliusApproves(oneDeltaManagement, nonce)
    nonce = await execLendleApproves(oneDeltaManagement, nonce)
    nonce = await execStratumApproves(oneDeltaManagement, nonce)

    console.log("deployment complete")
    console.log("======== Addresses =======")
    console.log("moduleConfig:", moduleConfig.address)
    console.log("proxy:", proxy.address)
    console.log("composer:", composer.address)
    console.log("management:", management.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
