import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import {
    ManagementModule,
    ManagementModule__factory,
    MarginTradeDataViewerModule,
    MarginTradeDataViewerModule__factory,
    DeltaBrokerProxy__factory,
    DeltaBrokerProxy,
    OwnershipModule__factory,
    ConfigModule__factory,
    LensModule__factory,
    AaveFlashModule__factory,
    BalancerFlashModule__factory,
    BalancerFlashModule,
    AaveFlashModule
} from "../../types";
import { ModuleConfigAction, getSelectors } from "../../test/diamond/libraries/diamond";

export const ONE_18 = BigNumber.from(10).pow(18)


export interface FlashBrokerFixture {
    flashBrokerAave: AaveFlashModule
    flashBrokerBalancer: BalancerFlashModule
    manager: ManagementModule
    tradeDataViewer: MarginTradeDataViewerModule
    proxy: DeltaBrokerProxy
}

export async function createFlashBroker(signer: SignerWithAddress, aavePool: string, balancerVault: string, opts: any = {}): Promise<FlashBrokerFixture> {
    let tx;

    // deploy ConfigModule
    const confgModule = await new ConfigModule__factory(signer).deploy(opts)
    console.log("Deploy config: ", confgModule.deployTransaction.hash)
    await confgModule.deployed()
    console.log("configModule:", confgModule.address)

    const proxy = await new DeltaBrokerProxy__factory(signer).deploy(
        signer.address,
        confgModule.address,
        opts
    )
    console.log("Deploy proxy: ", proxy.deployTransaction.hash)
    await proxy.deployed()
    console.log("flashBroker:", proxy.address)


    // get config module
    const configurator = await new ConfigModule__factory(signer).attach(proxy.address)

    // broker
    const brokerModuleAave = await new AaveFlashModule__factory(signer).deploy(
        aavePool,
        opts
    )
    await brokerModuleAave.deployed()
    console.log("brokerModuleAave:", brokerModuleAave.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: brokerModuleAave.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(brokerModuleAave)
        }],
        opts
    )
    await tx.wait()
    console.log("brokerModuleAave added")

    const flashBrokerAave = (await new ethers.Contract(proxy.address, AaveFlashModule__factory.createInterface(), signer) as AaveFlashModule)

    // broker
    const brokerModuleBalancer = await new BalancerFlashModule__factory(signer).deploy(
        aavePool,
        balancerVault,
        opts
    )
    await brokerModuleBalancer.deployed()
    console.log("brokerModuleBalancer:", brokerModuleBalancer.address)

    tx = await configurator.connect(signer).configureModules(
        [{
            moduleAddress: brokerModuleBalancer.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(brokerModuleBalancer)
        }],
        opts
    )
    await tx.wait()
    console.log("brokerModuleBalancer added")

    const flashBrokerBalancer = (await new ethers.Contract(proxy.address, BalancerFlashModule__factory.createInterface(), signer) as BalancerFlashModule)

    // manager
    const managerModule = await new ManagementModule__factory(signer).deploy(
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

    const manager = (await new ethers.Contract(proxy.address, ManagementModule__factory.createInterface(), signer) as ManagementModule)

    // viewer
    const viewerModule = await new MarginTradeDataViewerModule__factory(signer).deploy(
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

    // ownership
    const ownershipModule = await new OwnershipModule__factory(signer).deploy()
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
    console.log("brokerModuleBalancer:", brokerModuleBalancer.address)
    console.log("brokerModuleAave:", brokerModuleAave.address)
    console.log("managementModule:", managerModule.address)
    console.log("viewerModule:", viewerModule.address)

    return { flashBrokerAave, flashBrokerBalancer, proxy, manager, tradeDataViewer: viewerModule }

}