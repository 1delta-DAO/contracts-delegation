import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, ethers } from "ethers";
import {
    MarginTraderInit__factory,
    ManagementModule,
    ManagementModule__factory,
    DeltaBrokerProxy__factory,
    DeltaBrokerProxy,
    OwnershipModule__factory,
    ConfigModule__factory,
    LensModule__factory,
    DeltaFlashAggregatorMantle__factory,
    MarginTraderInit,
    DeltaFlashAggregatorMantle,
} from "../../../types";
import { ModuleConfigAction, getSelectors } from "../../../test/diamond/libraries/diamond";
import { AaveBrokerFixtureInclV2 } from "../../../test/1delta/shared/aaveBrokerFixture";

export const ONE_18 = BigNumber.from(10).pow(18)

const _opts = {}


export async function initializeLendleBroker(signer: SignerWithAddress, bf: AaveBrokerFixtureInclV2 | BrokerV2, pool: string, opts = _opts) {
    let tx;
    const dc = await new ConfigModule__factory(signer).attach(bf.brokerProxy.address)
    const initializer = await new MarginTraderInit__factory(signer).deploy(
        opts
    )
    await initializer.deployed()
    console.log("initializer:", initializer.address)

    tx = await dc.configureModules(
        [{
            moduleAddress: initializer.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initializer)
        }],
        opts
    )
    await tx.wait()

    const dcInit = await new ethers.Contract(bf.brokerProxy.address, MarginTraderInit__factory.createInterface(), signer) as MarginTraderInit


    tx = await dcInit.initMarginTrader(pool)
    await tx.wait()
    console.log("completed initialization")
}

export interface BrokerV2 {
    brokerProxy: DeltaBrokerProxy
    broker: DeltaFlashAggregatorMantle
    manager: ManagementModule
}

export async function createBrokerV2Mantle(signer: SignerWithAddress, opts = _opts): Promise<BrokerV2> {
    let tx;

    // deploy ConfigModule
    const configModule = await new ConfigModule__factory(signer).deploy()
    await configModule.deployed()
    console.log("configModule:", configModule.address)

    const proxy = await new DeltaBrokerProxy__factory(signer).deploy(
        signer.address,
        configModule.address,
        opts
    )
    await proxy.deployed()
    console.log("brokerProxy:", proxy.address)


    // get config module
    const configurator = await new ConfigModule__factory(signer).attach(proxy.address)

    // broker
    const brokerModule = await new DeltaFlashAggregatorMantle__factory(signer).deploy(
        opts
    )
    await brokerModule.deployed()
    console.log("flashAggregator:", brokerModule.address)

    const broker = (await new ethers.Contract(proxy.address, DeltaFlashAggregatorMantle__factory.createInterface(), signer) as DeltaFlashAggregatorMantle)

    // manager
    const managerModule = await new ManagementModule__factory(signer).deploy(
        opts
    )
    await managerModule.deployed()
    console.log("managementModule:", managerModule.address)

    const manager = (await new ethers.Contract(proxy.address, ManagementModule__factory.createInterface(), signer) as ManagementModule)

    // ownership
    const ownershipModule = await new OwnershipModule__factory(signer).deploy()
    await ownershipModule.deployed()
    console.log("ownership:", ownershipModule.address)


    // lens
    const lensModule = await new LensModule__factory(signer).deploy()
    await lensModule.deployed()
    console.log("ownership:", lensModule.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: managerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(managerModule)
        },
        {
            moduleAddress: lensModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(lensModule)
        },
        {
            moduleAddress: ownershipModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(ownershipModule)
        },
        {
            moduleAddress: brokerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(brokerModule)
        },
        ],
        opts
    )
    await tx.wait()
    console.log("lens added")

    console.log("--- All contracts ---")
    console.log("proxy:", proxy.address)
    console.log("configModule:", configModule.address)
    console.log("lens:", lensModule.address)
    console.log("ownership:", ownershipModule.address)
    console.log("marginTrader:", brokerModule.address)
    console.log("managementModule:", managerModule.address)

    return { broker, brokerProxy: proxy, manager }

}