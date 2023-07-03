import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import {
    CometMarginTraderModule,
    CometMarginTraderModule__factory,
    CometMarginTraderInit__factory,
    CometMoneyMarketModule,
    CometMoneyMarketModule__factory,
    CometManagementModule,
    CometManagementModule__factory,
    CometMarginTradeDataViewerModule,
    CometMarginTradeDataViewerModule__factory,
    UniswapV3ProviderInit__factory,
    CometUniV3Callback__factory,
    DeltaBrokerProxy__factory,
    DeltaBrokerProxy,
    CometMarginTraderInit,
    UniswapV3ProviderInit,
    OwnershipModule__factory,
    ConfigModule__factory,
    LensModule__factory,
    CometSweeperModule__factory,
    CometSweeperModule
} from "../../../types";
import { ModuleConfigAction, getSelectors } from "../../../test/diamond/libraries/diamond";
import { parseUnits } from "ethers/lib/utils";

export const ONE_18 = BigNumber.from(10).pow(18)

export interface CometBrokerFixture {
    brokerProxy: DeltaBrokerProxy
    broker: CometMarginTraderModule
    manager: CometManagementModule
    tradeDataViewer: CometMarginTradeDataViewerModule
    moneyMarket: CometMoneyMarketModule
    sweeper: CometSweeperModule
}

const usedMaxFeePerGas = parseUnits('100', 9)
const usedMaxPriorityFeePerGas = parseUnits('10', 9)

const _opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas,
    gasLimit: 3500000
}

export async function createBroker(signer: SignerWithAddress, uniFactory: string, opts: any = {}): Promise<CometBrokerFixture> {
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
    const brokerModule = await new CometMarginTraderModule__factory(signer).deploy(
        uniFactory,
        opts
    )
    await brokerModule.deployed()
    console.log("marginTrader:", brokerModule.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: brokerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(brokerModule)
        }],
        opts
    )
    await tx.wait()
    console.log("margin broker added")

    const broker = (await new ethers.Contract(proxy.address, CometMarginTraderModule__factory.createInterface(), signer) as CometMarginTraderModule)

    // manager
    const managerModule = await new CometManagementModule__factory(signer).deploy(
        opts
    )
    await managerModule.deployed()
    console.log("managementModule:", managerModule.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: managerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(managerModule)
        }],
        opts
    )
    await tx.wait()
    console.log("management added")

    const manager = (await new ethers.Contract(proxy.address, CometManagementModule__factory.createInterface(), signer) as CometManagementModule)

    // viewer
    const viewerModule = await new CometMarginTradeDataViewerModule__factory(signer).deploy(
        opts
    )
    await viewerModule.deployed()
    console.log("viewerModule:", viewerModule.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: viewerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(viewerModule)
        }],
        opts
    )
    await tx.wait()
    console.log("viewer added")

    // callback
    const callbackModule = await new CometUniV3Callback__factory(signer).deploy(
        uniFactory,
        opts
    )
    await callbackModule.deployed()
    console.log("callbackModule:", callbackModule.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: callbackModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(callbackModule)
        }],
        opts
    )
    await tx.wait()
    console.log("callback added")

    // money markets
    const moneyMarketModule = await new CometMoneyMarketModule__factory(signer).deploy(
        uniFactory,
        opts
    )
    await moneyMarketModule.deployed()
    console.log("moneyMarket:", moneyMarketModule.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: moneyMarketModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(moneyMarketModule)
        }],
        opts
    )
    await tx.wait()
    console.log("money market added")


    const moneyMarket = (await new ethers.Contract(proxy.address, CometMoneyMarketModule__factory.createInterface(), signer) as CometMoneyMarketModule)


    // money markets
    const sweeperModule = await new CometSweeperModule__factory(signer).deploy(uniFactory)
    await sweeperModule.deployed()
    console.log("sweeper:", sweeperModule.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: sweeperModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(sweeperModule)
        }],
        opts
    )
    await tx.wait()
    console.log("sweeper added")

    const sweeper = (await new ethers.Contract(proxy.address, CometSweeperModule__factory.createInterface(), signer) as CometSweeperModule)


    // ownership
    const ownershipModule = await new OwnershipModule__factory(signer).deploy(opts)
    await ownershipModule.deployed()
    console.log("ownership:", ownershipModule.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: ownershipModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(ownershipModule)
        }],
        opts
    )
    await tx.wait()
    console.log("ownership added")



    // lens
    const lensModule = await new LensModule__factory(signer).deploy()
    await lensModule.deployed()
    console.log("ownership:", lensModule.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: lensModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(lensModule)
        }],
        opts
    )
    await tx.wait()
    console.log("lens added")

    console.log("lens:", lensModule.address)
    console.log("ownership:", ownershipModule.address)
    console.log("marginTrader:", brokerModule.address)
    console.log("managementModule:", managerModule.address)
    console.log("viewerModule:", viewerModule.address)
    console.log("sweeper", sweeperModule.address)
    console.log("callbackModule:", callbackModule.address)
    console.log("moneyMarket:", moneyMarketModule.address)

    return { broker, brokerProxy: proxy, manager, tradeDataViewer: viewerModule, moneyMarket, sweeper }

}


export async function initializeBroker(signer: SignerWithAddress, bf: CometBrokerFixture, uniFactory: string, comet: string, weth: string, opts: any = {}) {
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

    const initUni = await new UniswapV3ProviderInit__factory(signer).deploy(
        opts
    )
    await initUni.deployed()
    console.log("initUni:", initUni.address)

    tx = await dc.configureModules(
        [{
            moduleAddress: initUni.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initUni)
        }],
        opts
    )
    await tx.wait()

    const dcInitUni = await new ethers.Contract(bf.brokerProxy.address, UniswapV3ProviderInit__factory.createInterface(), signer) as UniswapV3ProviderInit
    tx = await dcInitUni.initUniswapV3Provider(uniFactory, weth, opts)
    await tx.wait()

    console.log("completed initialization")
}
