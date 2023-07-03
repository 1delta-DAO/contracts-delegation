import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import {
    AAVEMarginTraderModule,
    AAVEMarginTraderModule__factory,
    AAVEMarginTraderInit__factory,
    AAVEMoneyMarketModule,
    AAVEMoneyMarketModule__factory,
    ManagementModule,
    ManagementModule__factory,
    MarginTradeDataViewerModule,
    MarginTradeDataViewerModule__factory,
    UniswapV3ProviderInit__factory,
    UniswapV3SwapCallbackModule__factory,
    DeltaBrokerProxy__factory,
    DeltaBrokerProxy,
    OneDeltaModuleManager,
    OneDeltaModuleManager__factory,
    AAVEMarginTraderInit,
    UniswapV3ProviderInit,
    ConfigModule,
    ConfigModule__factory,
    AAVESweeperModule__factory,
    AAVESweeperModule,
    MockRouter,
    MockBalancerVault,
    BalancerFlashModule__factory,
    BalancerFlashModule,
    AAVEFlashModule__factory,
    AAVEFlashModule
} from "../../../types";
import { ModuleConfigAction, getSelectors } from "../../diamond/libraries/diamond";
import { AAVEFixture } from "./aaveFixture";
import { UniswapFixtureNoTokens, UniswapMinimalFixtureNoTokens } from "./uniswapFixture";
import MoneyMarketArtifact from "../../../artifacts/contracts/1delta/modules/aave/AAVEMoneyMarketModule.sol/AAVEMoneyMarketModule.json"
import SweeperArtifact from "../../../artifacts/contracts/1delta/modules/aave/AAVESweeperModule.sol/AAVESweeperModule.json"
import MarginTraderArtifact from "../../../artifacts/contracts/1delta/modules/aave/AAVEMarginTraderModule.sol/AAVEMarginTraderModule.json"

export const ONE_18 = BigNumber.from(10).pow(18)

export interface AaveBrokerFixture {
    brokerProxy: DeltaBrokerProxy
    moduleConfig: ConfigModule
    broker: AAVEMarginTraderModule & AAVESweeperModule
    manager: ManagementModule
    tradeDataViewer: MarginTradeDataViewerModule
    moneyMarket: AAVEMoneyMarketModule & AAVESweeperModule
    sweeper: AAVESweeperModule
}

export async function aaveBrokerFixture(signer: SignerWithAddress, uniFactory: string, aavePool: string): Promise<AaveBrokerFixture> {


    const moduleConfig = await new ConfigModule__factory(signer).deploy()
    const proxy = await new DeltaBrokerProxy__factory(signer).deploy(signer.address, moduleConfig.address)
    const configContract = await new ConfigModule__factory(signer).attach(proxy.address)

    // broker
    const brokerModule = await new AAVEMarginTraderModule__factory(signer).deploy(uniFactory)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: brokerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(brokerModule)
        }]
    )


    // manager
    const managerModule = await new ManagementModule__factory(signer).deploy()

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: managerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(managerModule)
        }],
    )

    const manager = (await new ethers.Contract(proxy.address, ManagementModule__factory.createInterface(), signer) as ManagementModule)

    // viewer
    const viewerModule = await new MarginTradeDataViewerModule__factory(signer).deploy()

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: viewerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(viewerModule)
        }],
    )

    const tradeDataViewer = (await new ethers.Contract(proxy.address, MarginTradeDataViewerModule__factory.createInterface(), signer) as MarginTradeDataViewerModule)

    // callback
    const callbackModule = await new UniswapV3SwapCallbackModule__factory(signer).deploy(uniFactory, aavePool)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: callbackModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(callbackModule)
        }],
    )

    // money markets
    const moneyMarketModule = await new AAVEMoneyMarketModule__factory(signer).deploy(uniFactory, aavePool)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: moneyMarketModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(moneyMarketModule)
        }],
    )


    const sweeperModule = await new AAVESweeperModule__factory(signer).deploy(uniFactory, aavePool)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: sweeperModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(sweeperModule)
        }],
    )

    const sweeper = (await new ethers.Contract(proxy.address, AAVESweeperModule__factory.createInterface(), signer) as AAVESweeperModule)

    const broker = (await new ethers.Contract(
        proxy.address,
        [...SweeperArtifact.abi, ...MarginTraderArtifact.abi],
        signer
    ) as AAVEMarginTraderModule & AAVESweeperModule)

    const moneyMarket = (await new ethers.Contract(
        proxy.address,
        [...SweeperArtifact.abi, ...MoneyMarketArtifact.abi],
        signer) as AAVEMoneyMarketModule & AAVESweeperModule)


    return { broker, brokerProxy: proxy, manager, tradeDataViewer, moneyMarket, moduleConfig, sweeper }

}


export async function initAaveBroker(signer: SignerWithAddress, bf: AaveBrokerFixture, uniswapFixture: UniswapFixtureNoTokens | UniswapMinimalFixtureNoTokens | undefined, aave: AAVEFixture) {

    const dc = await new ethers.Contract(bf.brokerProxy.address, OneDeltaModuleManager__factory.createInterface(), signer) as OneDeltaModuleManager
    const initAAVE = await new AAVEMarginTraderInit__factory(signer).deploy()

    await dc.configureModules(
        [{
            moduleAddress: initAAVE.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initAAVE)
        }],
    )

    const dcInit = await new ethers.Contract(bf.brokerProxy.address, AAVEMarginTraderInit__factory.createInterface(), signer) as AAVEMarginTraderInit

    await dcInit.initAAVEMarginTrader(aave.pool.address)
    const initUni = await new UniswapV3ProviderInit__factory(signer).deploy()

    await dc.configureModules(
        [{
            moduleAddress: initUni.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initUni)
        }]
    )

    const dcInitUni = await new ethers.Contract(bf.brokerProxy.address, UniswapV3ProviderInit__factory.createInterface(), signer) as UniswapV3ProviderInit
    if (uniswapFixture) await dcInitUni.initUniswapV3Provider(uniswapFixture.factory.address, aave.tokens["WETH"].address)
}


export async function addBalancer(signer: SignerWithAddress, bf: AaveBrokerFixture, router: string, balancerVault: string, aavePool: string) {

    const dc = await new ethers.Contract(bf.brokerProxy.address, OneDeltaModuleManager__factory.createInterface(), signer) as OneDeltaModuleManager
    const balancerModule = await new BalancerFlashModule__factory(signer).deploy(aavePool, balancerVault)

    await dc.configureModules(
        [{
            moduleAddress: balancerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(balancerModule)
        }],
    )

    const data = await new ethers.Contract(bf.brokerProxy.address, BalancerFlashModule__factory.createInterface(), signer) as BalancerFlashModule

    await bf.manager.setValidTarget(router, true)

    return data
}


export async function addAaveFlashLoans(signer: SignerWithAddress, bf: AaveBrokerFixture, router: string, aavePool: string) {

    const dc = await new ethers.Contract(bf.brokerProxy.address, OneDeltaModuleManager__factory.createInterface(), signer) as OneDeltaModuleManager
    const balancerModule = await new AAVEFlashModule__factory(signer).deploy(aavePool)

    await dc.configureModules(
        [{
            moduleAddress: balancerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(balancerModule)
        }],
    )

    const data = await new ethers.Contract(bf.brokerProxy.address, AAVEFlashModule__factory.createInterface(), signer) as AAVEFlashModule

    await bf.manager.setValidTarget(router, true)

    return data
}
