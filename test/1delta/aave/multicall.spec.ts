import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { ethers, waffle } from 'hardhat'
import {
    ConfigModule,
    ConfigModule__factory,
    DeltaBrokerProxy,
    DeltaBrokerProxy__factory,
    MintableERC20,
    TestModuleA,
    TestModuleA__factory,
    TestModuleB,
    TestModuleB__factory,
    WETH9,
} from '../../../types';
import { MockProvider } from 'ethereum-waffle';
import { uniV2Fixture, V2Fixture } from '../shared/uniV2Fixture';
import { getSelectors, ModuleConfigAction } from '../../diamond/libraries/diamond';


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

})

// ··························|····················|·············|·············|·············|···············|··············
// |  DeltaBrokerProxy       ·  multicall         ·          -  ·          -  ·      37745  ·            1  ·       0.62  │
// ··························|····················|·············|·············|·············|···············|··············



    // // An efficient multicall implementation for delegatecalls
    // function multicall(bytes[] calldata data) external payable {
    //     // This is used in assembly below as impls.slot.
    //     mapping(bytes4 => address) storage impls = LibModules.moduleStorage().selectorToModule;
    //     for (uint256 i = 0; i != data.length; i++) {
    //         bytes calldata call = data[i];

    //         assembly {
    //             let selector := and(calldataload(call.offset), 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)
    //             mstore(0, selector)
    //             mstore(0x20, impls.slot)
    //             let slot := keccak256(0, 0x40)
    //             let delegate := sload(slot)
    //             if iszero(delegate) {
    //                 // Revert with:
    //                 // abi.encodeWithSelector(
    //                 //   bytes4(keccak256("NoImplementation(bytes4)")),
    //                 //   selector)
    //                 mstore(0, 0x734e6e1c00000000000000000000000000000000000000000000000000000000)
    //                 mstore(4, selector)
    //                 revert(0, 0x24)
    //             }
    //             calldatacopy(0, call.offset, call.length)
    //             let success := delegatecall(gas(), delegate, 0, call.length, 0, 0)
    //             let rdlen := returndatasize()
    //             returndatacopy(0, 0, rdlen)
    //             if iszero(success) {
    //                 revert(0, rdlen)
    //             }
    //         }
    //     }
    // }
