import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import {
    AaveMarginTraderInit__factory,
    ManagementModule,
    ManagementModule__factory,
    MarginTradeDataViewerModule,
    MarginTradeDataViewerModule__factory,
    DeltaBrokerProxy__factory,
    DeltaBrokerProxy,
    AaveMarginTraderInit,
    OwnershipModule__factory,
    ConfigModule__factory,
    LensModule__factory,
    DeltaFlashAggregator__factory,
    DeltaFlashAggregator,
    FlashAggregator,
    AaveFlashModule__factory,
    BalancerFlashModule__factory,
} from "../../types";
import { ModuleConfigAction, getSelectors } from "../../test/diamond/libraries/diamond";
import { parseUnits } from "ethers/lib/utils";
import { AaveBrokerFixtureInclV2 } from "../../test/1delta/shared/aaveBrokerFixture";

export const ONE_18 = BigNumber.from(10).pow(18)


const usedMaxFeePerGas = 48_000_000_000
const usedMaxPriorityFeePerGas = 48_000_000_000

const _opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas,
    // gasLimit: 4000000
}


export async function initializeBroker(signer: SignerWithAddress, bf: AaveBrokerFixtureInclV2 | BrokerV2, aavePool: string, opts = _opts) {
    let tx;
    const dc = await new ConfigModule__factory(signer).attach(bf.brokerProxy.address)
    const initAAVE = await new AaveMarginTraderInit__factory(signer).deploy(
        opts
    )
    await initAAVE.deployed()
    console.log("initAAVE:", initAAVE.address)

    tx = await dc.configureModules(
        [{
            moduleAddress: initAAVE.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initAAVE)
        }],
        opts
    )
    await tx.wait()

    const dcInit = await new ethers.Contract(bf.brokerProxy.address, AaveMarginTraderInit__factory.createInterface(), signer) as AaveMarginTraderInit


    tx = await dcInit.initAAVEMarginTrader(aavePool)
    await tx.wait()
    console.log("completed initialization")
}

export interface BrokerV2 {
    brokerProxy: DeltaBrokerProxy
    broker: FlashAggregator
    manager: ManagementModule
    tradeDataViewer: MarginTradeDataViewerModule
}

export async function createBrokerV2(signer: SignerWithAddress, balancer: string, aavePool: string, opts = _opts): Promise<BrokerV2> {
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
    const brokerModule = await new DeltaFlashAggregator__factory(signer).deploy(
        opts
    )
    await brokerModule.deployed()
    console.log("flashAggregator:", brokerModule.address)

    const broker = (await new ethers.Contract(proxy.address, DeltaFlashAggregator__factory.createInterface(), signer) as DeltaFlashAggregator)

    // manager
    const managerModule = await new ManagementModule__factory(signer).deploy(
        opts
    )
    await managerModule.deployed()
    console.log("managementModule:", managerModule.address)

    const manager = (await new ethers.Contract(proxy.address, ManagementModule__factory.createInterface(), signer) as ManagementModule)

    // viewer
    const viewerModule = await new MarginTradeDataViewerModule__factory(signer).deploy(
        opts
    )
    await viewerModule.deployed()
    console.log("viewerModule:", viewerModule.address)


    // ownership
    const ownershipModule = await new OwnershipModule__factory(signer).deploy()
    await ownershipModule.deployed()
    console.log("ownership:", ownershipModule.address)


    // lens
    const lensModule = await new LensModule__factory(signer).deploy()
    await lensModule.deployed()
    console.log("ownership:", lensModule.address)

    // broker aave
    const brokerModuleAave = await new AaveFlashModule__factory(signer).deploy(
        aavePool,
        opts
    )
    await brokerModuleAave.deployed()
    console.log("brokerModuleAave:", brokerModuleAave.address)

    // broker balancer
    const brokerModuleBalancer = await new BalancerFlashModule__factory(signer).deploy(
        aavePool,
        balancer,
        opts
    )
    await brokerModuleBalancer.deployed()
    console.log("brokerModuleBalancer:", brokerModuleBalancer.address)

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
            moduleAddress: viewerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(viewerModule)
        },
        {
            moduleAddress: brokerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(brokerModule)
        },
        {
            moduleAddress: brokerModuleAave.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(brokerModuleAave)
        },
        {
            moduleAddress: brokerModuleBalancer.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(brokerModuleBalancer)
        }
            ,],
        opts
    )
    await tx.wait()
    console.log("lens added")

    console.log("lens:", lensModule.address)
    console.log("ownership:", ownershipModule.address)
    console.log("marginTrader:", brokerModule.address)
    console.log("managementModule:", managerModule.address)
    console.log("viewerModule:", viewerModule.address)
    console.log("brokerModuleAave:", brokerModuleAave.address)
    console.log("brokerModuleBalancer:", brokerModuleBalancer.address)

    return { broker, brokerProxy: proxy, manager, tradeDataViewer: viewerModule }

}