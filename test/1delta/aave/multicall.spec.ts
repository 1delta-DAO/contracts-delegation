import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { ethers, waffle } from 'hardhat'
import {
    ConfigModule,
    ConfigModule__factory,
    DeltaBrokerProxy,
    DeltaBrokerProxy__factory,
    ERC20Base__factory,
    ERC20__factory,
    MintableERC20,
    TestModuleA,
    TestModuleA__factory,
    TestModuleB,
    TestModuleB__factory,
    TestModuleC__factory,
    WETH9,
} from '../../../types';
import { MockProvider } from 'ethereum-waffle';
import { uniV2Fixture, V2Fixture } from '../shared/uniV2Fixture';
import { getSelectors, ModuleConfigAction } from '../../diamond/libraries/diamond';
import { expect } from 'chai';


// we prepare a setup for aave in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('Multicall on raw Proxy', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let achi: SignerWithAddress;
    let wally: SignerWithAddress;
    let dennis: SignerWithAddress;
    let vlad: SignerWithAddress;
    let xander: SignerWithAddress;
    let test0: SignerWithAddress;
    let test1: SignerWithAddress;
    let test2: SignerWithAddress;
    let test3: SignerWithAddress;
    let provider: MockProvider
    let moduleConfig: ConfigModule
    let proxy: DeltaBrokerProxy
    let moduleA: TestModuleA
    let moduleB: TestModuleB

    before('Deploy Account, Trader, Uniswap and AAVE', async () => {
        [deployer, alice, bob, carol, gabi, achi, wally, dennis,
            vlad, xander, test0, test1, test2, test3] = await ethers.getSigners();
        provider = waffle.provider;


        moduleConfig = await new ConfigModule__factory(deployer).deploy()
        proxy = await new DeltaBrokerProxy__factory(deployer).deploy(deployer.address, moduleConfig.address)
        const configContract = await new ConfigModule__factory(deployer).attach(proxy.address)

        moduleA = await new TestModuleA__factory(deployer).deploy()
        moduleB = await new TestModuleB__factory(deployer).deploy()

        await configContract.connect(deployer).configureModules(
            [
                {
                    moduleAddress: moduleA.address,
                    action: ModuleConfigAction.Add,
                    functionSelectors: getSelectors(moduleA)
                },
                {
                    moduleAddress: moduleB.address,
                    action: ModuleConfigAction.Add,
                    functionSelectors: getSelectors(moduleB)
                },
            ],
        )

    })

    it('multicall', async () => {

        const call1 = moduleA.interface.encodeFunctionData('testAFunc1', [88])
        const call2 = moduleB.interface.encodeFunctionData('testBFunc20')

        await proxy.multicall([call1, call2])
    })

    it('throws correct error', async () => {

        const call1 = ERC20Base__factory.createInterface().encodeFunctionData('totalSupply')
        const call2 = moduleB.interface.encodeFunctionData('testBFunc20')

        // test for multicall
        await expect(proxy.multicall([call1, call2])).to.be.revertedWith('noImplementation()')
        // test for base call
        const newCont = await new TestModuleC__factory(deployer).attach(proxy.address)
        await expect(newCont.testCFunc1()).to.be.revertedWith('noImplementation()')
    })

})

// ··························|····················|·············|·············|·············|···············|··············
// |  DeltaBrokerProxy       ·  multicall         ·          -  ·          -  ·      37594  ·            1  ·       0.74  │
// ··························|····················|·············|·············|·············|···············|··············
