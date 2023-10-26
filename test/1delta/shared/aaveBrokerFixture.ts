import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, constants } from "ethers";
import { ethers } from "hardhat";
import {
    ManagementModule,
    ManagementModule__factory,
    DeltaBrokerProxy__factory,
    DeltaBrokerProxy,
    OneDeltaModuleManager,
    OneDeltaModuleManager__factory,
    ConfigModule,
    ConfigModule__factory,
    BalancerFlashModule__factory,
    BalancerFlashModule,
    AaveFlashModule__factory,
    AaveFlashModule,
    FlashAggregator__factory,
    FlashAggregator,
    AaveMarginTraderInit__factory,
    AaveMarginTraderInit,
    VariableDebtToken,
    StableDebtToken,
    AToken
} from "../../../types";
import { ModuleConfigAction, getSelectors } from "../../diamond/libraries/diamond";
import FlashAggregatorArtifact from "../../../artifacts/contracts/1delta/modules/aave/FlashAggregator.sol/FlashAggregator.json"
import { buildDelegationWithSigParams, buildPermitParams, getSignatureFromTypedData } from "./contracts-helpers";

export const ONE_18 = BigNumber.from(10).pow(18)



export async function addBalancer(signer: SignerWithAddress, bf: AaveBrokerFixtureInclV2, router: string, balancerVault: string, aavePool: string) {

    const dc = await new ethers.Contract(bf.brokerProxy.address, OneDeltaModuleManager__factory.createInterface(), signer) as OneDeltaModuleManager
    const balancerModule = await new BalancerFlashModule__factory(signer).deploy(aavePool, balancerVault)

    await dc.configureModules(
        [{
            moduleAddress: balancerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(balancerModule)
        }],
    )

    const delta = await new ethers.Contract(bf.brokerProxy.address, BalancerFlashModule__factory.createInterface(), signer) as BalancerFlashModule

    await bf.manager.setValidTarget(router, true)

    return { delta, balancerModule }
}


export async function addAaveFlashLoans(signer: SignerWithAddress, bf: AaveBrokerFixtureInclV2, router: string, aavePool: string) {

    const dc = await new ethers.Contract(bf.brokerProxy.address, OneDeltaModuleManager__factory.createInterface(), signer) as OneDeltaModuleManager
    const balancerModule = await new AaveFlashModule__factory(signer).deploy(aavePool)

    await dc.configureModules(
        [{
            moduleAddress: balancerModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(balancerModule)
        }],
    )

    const data = await new ethers.Contract(bf.brokerProxy.address, AaveFlashModule__factory.createInterface(), signer) as AaveFlashModule

    await bf.manager.setValidTarget(router, true)

    return data
}



export interface AaveBrokerFixtureInclV2 {
    brokerProxy: DeltaBrokerProxy
    moduleConfig: ConfigModule
    manager: ManagementModule
    moneyMarket: FlashAggregator
    moneyMarketImplementation: FlashAggregator
    trader: FlashAggregator
}

export async function aaveBrokerFixtureInclV2(signer: SignerWithAddress, uniFactory: string, aavePool: string, uniV2Factory: string, weth: string): Promise<AaveBrokerFixtureInclV2> {


    const moduleConfig = await new ConfigModule__factory(signer).deploy()
    const proxy = await new DeltaBrokerProxy__factory(signer).deploy(signer.address, moduleConfig.address)
    const configContract = await new ConfigModule__factory(signer).attach(proxy.address)

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

    const moneyMarketModule = await new FlashAggregator__factory(signer).deploy(uniV2Factory, uniFactory, aavePool, weth)

    await configContract.connect(signer).configureModules(
        [{
            moduleAddress: moneyMarketModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(moneyMarketModule)
        }],
    )

    const moneyMarket = (await new ethers.Contract(
        proxy.address,
        FlashAggregatorArtifact.abi,
        signer) as FlashAggregator)

    const trader = (await new ethers.Contract(
        proxy.address,
        FlashAggregatorArtifact.abi,
        signer
    ) as FlashAggregator)
    return { trader, brokerProxy: proxy, manager, moneyMarket, moduleConfig, moneyMarketImplementation: moneyMarketModule }

}



export async function initAaveBroker(signer: SignerWithAddress, bf: AaveBrokerFixtureInclV2, aavePool: string) {

    const dc = await new ethers.Contract(bf.brokerProxy.address, OneDeltaModuleManager__factory.createInterface(), signer) as OneDeltaModuleManager
    const initAAVE = await new AaveMarginTraderInit__factory(signer).deploy()

    await dc.configureModules(
        [{
            moduleAddress: initAAVE.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initAAVE)
        }],
    )
    const dcInit = await new ethers.Contract(bf.brokerProxy.address, AaveMarginTraderInit__factory.createInterface(), signer) as AaveMarginTraderInit

    await dcInit.initAaveMarginTrader(aavePool)
}

const EIP712_REVISION = '1';

export async function createDelegationPermit(signer: SignerWithAddress, token: VariableDebtToken | StableDebtToken, amount: string, target: string, chainId: number): Promise<{
    v: number, r: string, s: string, expiration: string
}> {
    const expiration = constants.MaxUint256.toString();
    const nonce = (await token.nonces(signer.address)).toNumber();
    const msgParams = buildDelegationWithSigParams(
        chainId,
        token.address,
        EIP712_REVISION,
        await token.name(),
        target,
        nonce,
        expiration,
        amount.toString()
    );

    const { v, r, s } = await getSignatureFromTypedData(
        signer,
        msgParams.domain,
        {
            DelegationWithSig: msgParams.types.DelegationWithSig
        },
        msgParams.message);

    return { v, r, s, expiration }
}


export async function createPermit(signer: SignerWithAddress, token: AToken, amount: string, target: string, chainId: number): Promise<{
    v: number, r: string, s: string, expiration: string
}> {
    const expiration = constants.MaxUint256.toString();
    const nonce = (await token.nonces(signer.address)).toNumber();
    const msgParams = buildPermitParams(
        chainId,
        token.address,
        EIP712_REVISION,
        await token.name(),
        signer.address,
        target,
        nonce,
        expiration,
        amount.toString()
    );

    const { v, r, s } = await getSignatureFromTypedData(
        signer,
        msgParams.domain,
        {
            Permit: msgParams.types.Permit
        },
        msgParams.message);

    return { v, r, s, expiration }
} 