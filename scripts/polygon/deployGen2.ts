
import { ethers } from "hardhat";
import {
    DeltaBrokerProxyGen2__factory,
    ConfigModule__factory,
    PolygonManagementModule__factory,
    OneDeltaComposerPolygon__factory,
    LensModule__factory,
} from "../../types";
import { getPolygonConfig } from "./utils";
import { ModuleConfigAction, getContractSelectors } from "../../test-ts/libraries/diamond";
import { addAaveV2Tokens, addAaveV3Tokens, addYldrTokens } from "./lenders/addLenderData";
import { execAaveV2Approves, execAaveV3Approves, execCompoundV3USDCEApproves, execYldrApproves } from "./approvals/approveAddress";

const aggregatorsTargets = [
    '0x4E3288c9ca110bCC82bf38F09A7b425c095d92Bf', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // KYBER
    '0x6a000f20005980200259b80c5102003040001068', // PARASWAP,
    '0x1111111254eeb25477b68fb85ed929f73a960582' // 1inch
]

const aggregatorsToApproves = [
    '0x4E3288c9ca110bCC82bf38F09A7b425c095d92Bf', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // KYBER
    '0x6a000f20005980200259b80c5102003040001068', // PARASWAP TRANSFER PTOXY
    '0x1111111254eeb25477b68fb85ed929f73a960582' // 1inch
]

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 137) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()
    // deploy module config
    const moduleConfig = await new ConfigModule__factory(operator).deploy(getPolygonConfig(nonce++))
    await moduleConfig.deployed()

    console.log("moduleConfig deployed")

    // deploy proxy
    const proxy = await new DeltaBrokerProxyGen2__factory(operator).deploy(
        operator.address,
        moduleConfig.address,
        getPolygonConfig(nonce++)
    )
    await proxy.deployed()

    console.log("proxy deployed")

    // deploy modules

    const lens = await new LensModule__factory(operator).deploy(getPolygonConfig(nonce++))
    await lens.deployed()


    // management
    const management = await new PolygonManagementModule__factory(operator).deploy(getPolygonConfig(nonce++))
    await management.deployed()

    // composer
    const composer = await new OneDeltaComposerPolygon__factory(operator).deploy(getPolygonConfig(nonce++))
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

    let tx = await oneDeltaModuleConfig.configureModules(cut, getPolygonConfig(nonce++))
    await tx.wait()
    console.log("modules added")
    const oneDeltaManagement = await new PolygonManagementModule__factory(operator).attach(proxy.address)

    // add aggregators
    tx = await oneDeltaManagement.setValidTarget(aggregatorsToApproves[0], aggregatorsTargets[0], true, getPolygonConfig(nonce++))
    await tx.wait()
    tx = await oneDeltaManagement.setValidTarget(aggregatorsToApproves[1], aggregatorsTargets[1], true, getPolygonConfig(nonce++))
    await tx.wait()
    tx = await oneDeltaManagement.setValidTarget(aggregatorsToApproves[2], aggregatorsTargets[2], true, getPolygonConfig(nonce++))
    await tx.wait()
    tx = await oneDeltaManagement.setValidTarget(aggregatorsToApproves[3], aggregatorsTargets[3], true, getPolygonConfig(nonce++))
    await tx.wait()


    // add lender data
    nonce = await addAaveV3Tokens(oneDeltaManagement, nonce)
    nonce = await addAaveV2Tokens(oneDeltaManagement, nonce)
    nonce = await addYldrTokens(oneDeltaManagement, nonce)

    // approve targets
    nonce = await execAaveV2Approves(oneDeltaManagement, nonce)
    nonce = await execAaveV3Approves(oneDeltaManagement, nonce)
    nonce = await execYldrApproves(oneDeltaManagement, nonce)
    nonce = await execCompoundV3USDCEApproves(oneDeltaManagement, nonce)

    console.log("deployment complete")
    console.log("======== Addresses =======")
    console.log("moduleConfig:", moduleConfig.address)
    console.log("proxy:", proxy.address)
    console.log("composerImplementation:", composer.address)
    console.log("managementImplementation:", management.address)
    console.log("lensImplementation:", lens.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
