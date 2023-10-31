import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import {
    CometMarginTraderInit__factory,
    CometManagementModule,
    CometManagementModule__factory,
    DeltaBrokerProxy__factory,
    DeltaBrokerProxy,
    CometMarginTraderInit,
    OwnershipModule__factory,
    ConfigModule__factory,
    CometFlashAggregatorPolygon,
    CometFlashAggregatorPolygon__factory,
    LensModule__factory
} from "../../../types";
import { ModuleConfigAction, getSelectors } from "../../../test/diamond/libraries/diamond";
import { parseUnits } from "ethers/lib/utils";

export const ONE_18 = BigNumber.from(10).pow(18)

export interface CometBrokerFixture {
    brokerProxy: DeltaBrokerProxy
    broker: CometFlashAggregatorPolygon
    manager: CometManagementModule
}

const usedMaxFeePerGas = parseUnits('100', 9)
const usedMaxPriorityFeePerGas = parseUnits('10', 9)

const _opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas,
    // gasLimit: 3500000
}

export async function createBroker(signer: SignerWithAddress, opts: any = {}): Promise<CometBrokerFixture> {
    let tx;

    // deploy ConfigModule
    const confgModule = await new ConfigModule__factory(signer).deploy()
    await confgModule.deployed()
    console.log("configModule:", confgModule.address)

    const proxy = await new DeltaBrokerProxy__factory(signer).deploy(
        signer.address,
        confgModule.address,
        opts
    )
    await proxy.deployed()
    console.log("brokerProxy:", proxy.address)


    // get config module
    const configurator = await new ConfigModule__factory(signer).attach(proxy.address)

    // broker
    const brokerModule = await new CometFlashAggregatorPolygon__factory(signer).deploy(
        opts
    )
    await brokerModule.deployed()
    console.log("marginTrader:", brokerModule.address)

    const broker = (await new ethers.Contract(proxy.address, CometFlashAggregatorPolygon__factory.createInterface(), signer) as CometFlashAggregatorPolygon)

    // manager
    const managerModule = await new CometManagementModule__factory(signer).deploy(
        opts
    )
    await managerModule.deployed()
    console.log("managementModule:", managerModule.address)


    const manager = (await new ethers.Contract(proxy.address, CometManagementModule__factory.createInterface(), signer) as CometManagementModule)

    // ownership
    const ownershipModule = await new OwnershipModule__factory(signer).deploy(opts)
    await ownershipModule.deployed()
    console.log("ownership:", ownershipModule.address)


    // lens
    const lensModule = await new LensModule__factory(signer).deploy()
    await lensModule.deployed()
    console.log("lens:", lensModule.address)

    tx = await configurator.connect(signer).configureModules(
        [
            {
                moduleAddress: brokerModule.address,
                action: ModuleConfigAction.Add,
                functionSelectors: getSelectors(brokerModule)
            },

            {
                moduleAddress: managerModule.address,
                action: ModuleConfigAction.Add,
                functionSelectors: getSelectors(managerModule)
            },
            {
                moduleAddress: ownershipModule.address,
                action: ModuleConfigAction.Add,
                functionSelectors: getSelectors(ownershipModule)
            },
            {
                moduleAddress: lensModule.address,
                action: ModuleConfigAction.Add,
                functionSelectors: getSelectors(lensModule)
            }
        ],
        opts
    )
    await tx.wait()
    console.log("modulkes added")

    console.log("---- addresses ---")
    console.log("proxy:", proxy.address)
    console.log("configModule:", confgModule.address)
    console.log("lens:", lensModule.address)
    console.log("ownership:", ownershipModule.address)
    console.log("marginTrader:", brokerModule.address)
    console.log("managementModule:", managerModule.address)

    return { broker, brokerProxy: proxy, manager }

}


export async function initializeBroker(signer: SignerWithAddress, bf: CometBrokerFixture, comet: string, opts: any = {}) {
    let tx;
    const dc = await new ConfigModule__factory(signer).attach(bf.brokerProxy.address)
    const initComet = await new CometMarginTraderInit__factory(signer).deploy(
        opts
    )
    await initComet.deployed()
    console.log("initComet:", initComet.address)

    tx = await dc.configureModules(
        [{
            moduleAddress: initComet.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initComet)
        }],
        opts
    )
    await tx.wait()

    const dcInit = await new ethers.Contract(bf.brokerProxy.address, CometMarginTraderInit__factory.createInterface(), signer) as CometMarginTraderInit

    tx = await dcInit.initCometMarginTrader(comet, opts)
    await tx.wait()

    console.log("completed initialization")
}
