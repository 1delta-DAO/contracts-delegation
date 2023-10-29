import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, constants } from "ethers";
import { ethers } from "hardhat";
import {
    CometMarginTraderInit__factory,
    CometManagementModule,
    CometManagementModule__factory,
    DeltaBrokerProxy__factory,
    DeltaBrokerProxy,
    OneDeltaModuleManager,
    OneDeltaModuleManager__factory,
    ConfigModule,
    ConfigModule__factory,
    CometSweeperModule__factory,
    CometSweeperModule,
    CometFlashAggregator__factory,
    CometFlashAggregator
} from "../../../types";
import { ModuleConfigAction, getSelectors } from "../../diamond/libraries/diamond";
import { UniswapFixtureNoTokens, UniswapMinimalFixtureNoTokens } from "./uniswapFixture";
import FlashAggregatorArtifact from "../../../artifacts/contracts/1delta/modules/comet/FlashAggregator.sol/CometFlashAggregator.json"
import { CompoundV3Protocol, exp } from "./compoundV3Fixture";

export const ONE_18 = BigNumber.from(10).pow(18)

export interface CometBrokerFixture {
    brokerProxy: DeltaBrokerProxy
    moduleConfig: ConfigModule
    broker: CometFlashAggregator
    manager: CometManagementModule
    moneyMarket: CometFlashAggregator
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


export async function cometBrokerFixture(signer: SignerWithAddress, uniFactory: string, uniFactoryV2 = constants.AddressZero, weth = constants.AddressZero): Promise<CometBrokerFixture> {

    const moduleConfig = await new ConfigModule__factory(signer).deploy()
    const proxy = await new DeltaBrokerProxy__factory(signer).deploy(signer.address, moduleConfig.address)
    const configContract = await new ConfigModule__factory(signer).attach(proxy.address)

    // broker
    const brokerModule = await new CometFlashAggregator__factory(signer).deploy(uniFactory, uniFactoryV2, weth)

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
        FlashAggregatorArtifact.abi,
        signer
    ) as CometFlashAggregator)

    const moneyMarket = (await new ethers.Contract(
        proxy.address,
        FlashAggregatorArtifact.abi,
        signer) as CometFlashAggregator)


    return { broker, brokerProxy: proxy, manager, moneyMarket, moduleConfig, sweeper }

}


export async function initCometBroker(signer: SignerWithAddress, bf: CometBrokerFixture, comet:string) {

    const dc = await new ethers.Contract(bf.brokerProxy.address, OneDeltaModuleManager__factory.createInterface(), signer) as OneDeltaModuleManager
    const initComet = await new CometMarginTraderInit__factory(signer).deploy()

    await dc.configureModules(
        [{
            moduleAddress: initComet.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initComet)
        }],
    )

    const inuit = await new CometMarginTraderInit__factory(signer).attach(bf.brokerProxy.address)
    await inuit.initCometMarginTrader(comet)


}
