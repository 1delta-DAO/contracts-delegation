import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, constants } from "ethers";
import { ethers } from "hardhat";
import {
    DeltaBrokerProxy__factory,
    DeltaBrokerProxy,
    OneDeltaModuleManager,
    OneDeltaModuleManager__factory,
    ConfigModule,
    ConfigModule__factory,
    FlashAggregator,
    VenusMarginTraderInit__factory,
    VenusMarginTraderInit,
    VenusManagementModule__factory,
    VenusManagementModule,
    VenusFlashAggregator__factory,
    VenusFlashAggregator
} from "../../../types";
import { ModuleConfigAction, getSelectors } from "../../libraries/diamond";
import FlashAggregatorArtifact from "../../../artifacts/contracts/1delta/modules/venus/FlashAggregator.sol/VenusFlashAggregator.json"

export const ONE_18 = BigNumber.from(10).pow(18)


export interface VenusBrokerFixture {
    brokerProxy: DeltaBrokerProxy
    moduleConfig: ConfigModule
    manager: VenusManagementModule
    aggregatorImplementation: VenusFlashAggregator
    aggregator: VenusFlashAggregator
}

export async function venusBrokerFixture(signer: SignerWithAddress, weth: string, cNative: string): Promise<VenusBrokerFixture> {


    const moduleConfig = await new ConfigModule__factory(signer).deploy()
    const proxy = await new DeltaBrokerProxy__factory(signer).deploy(signer.address, moduleConfig.address)
    const configContract = await new ConfigModule__factory(signer).attach(proxy.address)

    // manager
    const managerModule = await new VenusManagementModule__factory(signer).deploy()

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: managerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(managerModule)
        }],
    )

    const manager = (await new ethers.Contract(proxy.address, VenusManagementModule__factory.createInterface(), signer) as VenusManagementModule)

    const flashModule = await new VenusFlashAggregator__factory(signer).deploy(cNative, weth)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: flashModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(flashModule)
        }],
    )

    const moneyMarket = (await new ethers.Contract(
        proxy.address,
        FlashAggregatorArtifact.abi,
        signer) as FlashAggregator)

    const aggregator = (await new ethers.Contract(
        proxy.address,
        FlashAggregatorArtifact.abi,
        signer
    ) as VenusFlashAggregator)
    return { aggregator, brokerProxy: proxy, manager, moduleConfig, aggregatorImplementation: flashModule }

}



export async function initVenusBroker(signer: SignerWithAddress, bf: VenusBrokerFixture, comptroller: string) {

    const dc = await new ethers.Contract(bf.brokerProxy.address, OneDeltaModuleManager__factory.createInterface(), signer) as OneDeltaModuleManager
    const initVenus = await new VenusMarginTraderInit__factory(signer).deploy()

    await dc.configureModules(
        [{
            moduleAddress: initVenus.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initVenus)
        }],
    )
    const dcInit = await new ethers.Contract(bf.brokerProxy.address, VenusMarginTraderInit__factory.createInterface(), signer) as VenusMarginTraderInit

    await dcInit.initVenusMarginTrader(comptroller)
}
