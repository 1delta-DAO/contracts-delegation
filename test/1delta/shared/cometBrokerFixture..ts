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
    OneDeltaModuleManager,
    OneDeltaModuleManager__factory,
    CometMarginTraderInit,
    UniswapV3ProviderInit,
    ConfigModule,
    ConfigModule__factory,
    CometSweeperModule__factory,
    CometSweeperModule
} from "../../../types";
import { ModuleConfigAction, getSelectors } from "../../diamond/libraries/diamond";
import { UniswapFixtureNoTokens, UniswapMinimalFixtureNoTokens } from "./uniswapFixture";
import MoneyMarketArtifact from "../../../artifacts/contracts/1delta/modules/comet/CometMoneyMarketModule.sol/CometMoneyMarketModule.json"
import SweeperArtifact from "../../../artifacts/contracts/1delta/modules/comet/CometSweeperModule.sol/CometSweeperModule.json"
import MarginTraderArtifact from "../../../artifacts/contracts/1delta/modules/comet/CometMarginTraderModule.sol/CometMarginTraderModule.json"
import { CompoundV3Protocol, exp } from "./compoundV3Fixture";

export const ONE_18 = BigNumber.from(10).pow(18)

export interface CometBrokerFixture {
    brokerProxy: DeltaBrokerProxy
    moduleConfig: ConfigModule
    broker: CometMarginTraderModule & CometSweeperModule
    manager: CometManagementModule
    tradeDataViewer: CometMarginTradeDataViewerModule
    moneyMarket: CometMoneyMarketModule & CometSweeperModule
    sweeper: CometSweeperModule
}

// we do not need to care for decimals in our tests
export const TestConfig1delta = {
    AAVE: {
        initial: 1e7,
        decimals: 18,
        initialPrice: 1, // 1 COMP = 1 USDC
        borrowCF: exp(0.75, 18),
        liquidateCF: exp(0.8, 18),
        supplyCap: exp(1e8, 18)
    },
    USDC: Object.assign({
        initial: 1e6,
        decimals: 18,
        borrowCF: exp(0.75, 18),
        liquidateCF: exp(0.8, 18),
        supplyCap: exp(1e8, 18)
    }),
    USDT: Object.assign({
        initial: 1e6,
        decimals: 18,
        borrowCF: exp(0.75, 18),
        liquidateCF: exp(0.8, 18),
        supplyCap: exp(1e8, 18)
    }),
    DAI: Object.assign({
        initial: 1e6,
        decimals: 18,
        initialPrice: 1,
        borrowCF: exp(0.75, 18),
        liquidateCF: exp(0.8, 18),
        supplyCap: exp(1e8, 18)
    }),
    WETH: Object.assign({
        initial: 1e4,
        decimals: 18,
        initialPrice: 1,
        borrowCF: exp(0.75, 18),
        liquidateCF: exp(0.8, 18),
        supplyCap: exp(1e8, 18)
    }),
    WMATIC: Object.assign({
        initial: 1e3,
        decimals: 18,
        initialPrice: 1,
        borrowCF: exp(0.75, 18),
        liquidateCF: exp(0.8, 18),
        supplyCap: exp(1e8, 18)
    }),
    TEST1: Object.assign({
        initial: 1e3,
        decimals: 18,
        initialPrice: 1,
        borrowCF: exp(0.75, 18),
        liquidateCF: exp(0.8, 18),
        supplyCap: exp(1e8, 18)
    }),
    TEST2: Object.assign({
        initial: 1e3,
        decimals: 18,
        initialPrice: 1,
        borrowCF: exp(0.75, 18),
        liquidateCF: exp(0.8, 18),
        supplyCap: exp(1e8, 18)
    }),
};


export async function cometBrokerFixture(signer: SignerWithAddress,  uniFactory: string): Promise<CometBrokerFixture> {

    const moduleConfig = await new ConfigModule__factory(signer).deploy()
    const proxy = await new DeltaBrokerProxy__factory(signer).deploy(signer.address, moduleConfig.address)
    const configContract = await new ConfigModule__factory(signer).attach(proxy.address)

    // broker
    const brokerModule = await new CometMarginTraderModule__factory(signer).deploy(uniFactory)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: brokerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(brokerModule)
        }]
    )


    // manager
    const managerModule = await new CometManagementModule__factory(signer).deploy()

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: managerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(managerModule)
        }],
    )

    const manager = (await new ethers.Contract(
        proxy.address, 
        CometManagementModule__factory.createInterface(), 
        signer
        ) as CometManagementModule)

    // viewer
    const viewerModule = await new CometMarginTradeDataViewerModule__factory(signer).deploy()

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: viewerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(viewerModule)
        }],
    )

    const tradeDataViewer = (await new ethers.Contract(
        proxy.address, CometMarginTradeDataViewerModule__factory.createInterface(), signer
        ) as CometMarginTradeDataViewerModule)

    // callback
    const callbackModule = await new CometUniV3Callback__factory(signer).deploy(uniFactory)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: callbackModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(callbackModule)
        }],
    )

    // money markets
    const moneyMarketModule = await new CometMoneyMarketModule__factory(signer).deploy(uniFactory)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: moneyMarketModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(moneyMarketModule)
        }],
    )


    const sweeperModule = await new CometSweeperModule__factory(signer).deploy(uniFactory)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: sweeperModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(sweeperModule)
        }],
    )

    const sweeper = (await new ethers.Contract(proxy.address, CometSweeperModule__factory.createInterface(), signer) as CometSweeperModule)

    const broker = (await new ethers.Contract(
        proxy.address,
        [...SweeperArtifact.abi, ...MarginTraderArtifact.abi],
        signer
    ) as CometMarginTraderModule & CometSweeperModule)

    const moneyMarket = (await new ethers.Contract(
        proxy.address,
        [...SweeperArtifact.abi, ...MoneyMarketArtifact.abi],
        signer) as CometMoneyMarketModule & CometSweeperModule)


    return { broker, brokerProxy: proxy, manager, tradeDataViewer, moneyMarket, moduleConfig, sweeper }

}


export async function initCometBroker(signer: SignerWithAddress, bf: CometBrokerFixture, uniswapFixture: UniswapFixtureNoTokens | UniswapMinimalFixtureNoTokens, compound: CompoundV3Protocol) {

    const dc = await new ethers.Contract(bf.brokerProxy.address, OneDeltaModuleManager__factory.createInterface(), signer) as OneDeltaModuleManager
    const initComet = await new CometMarginTraderInit__factory(signer).deploy()

    await dc.configureModules(
        [{
            moduleAddress: initComet.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initComet)
        }],
    )

    const dcInit = await new ethers.Contract(bf.brokerProxy.address, CometMarginTraderInit__factory.createInterface(), signer) as CometMarginTraderInit


    await dcInit.initCometMarginTrader(compound.comet.address)
    const initUni = await new UniswapV3ProviderInit__factory(signer).deploy()

    await dc.configureModules(
        [{
            moduleAddress: initUni.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initUni)
        }]
    )

    const dcInitUni = await new ethers.Contract(bf.brokerProxy.address, UniswapV3ProviderInit__factory.createInterface(), signer) as UniswapV3ProviderInit
    await dcInitUni.initUniswapV3Provider(uniswapFixture.factory.address, compound.tokens["WETH"].address)
}
