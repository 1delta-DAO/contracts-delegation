import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat'
import { MintableERC20, WETH9 } from '../../types';
import { CompoundV3Protocol, makeProtocol, testAssets } from '../1delta/shared/compoundV3Fixture';
import { expandTo18Decimals } from '../uniswap-v3/periphery/shared/expandTo18Decimals';

// we prepare a setup for compound in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('CompoundV3 setup', async () => {
    let deployer: SignerWithAddress, alice: SignerWithAddress, bob: SignerWithAddress, carol: SignerWithAddress;
    let tokens: (MintableERC20 | WETH9)[];
    let compound: CompoundV3Protocol

    before('Deploy Account, Trader, Uniswap and Compound', async () => {
        [deployer, alice, bob, carol] = await ethers.getSigners();

    })

    it('deploys everything', async () => {
        compound = await makeProtocol({ base: 'USDC', targetReserves: 0, assets: testAssets });

        const tokens = Object.values(compound.tokens)
        const keys = Object.keys(compound.tokens)
        for (let i = 0; i < tokens.length; i++) {
            const key = keys[i]
            console.log(key)
            if (key === 'WETH') {
                compound.tokens['WETH'].deposit({ value: expandTo18Decimals(1_000) })
            } else {
                try {

                    const p = await compound.comet.getAssetInfo(i)
                    const pp = await compound.comet.getPrice(p.priceFeed)
                    console.log("price", pp.toString())
                    console.log(p.borrowCollateralFactor.toString(), p.supplyCap.toString())

                } catch (e) { console.log(e) }
                await tokens[i].connect(deployer).allocateTo(alice.address, expandTo18Decimals(100_000_000))
                await tokens[i].connect(deployer).allocateTo(bob.address, expandTo18Decimals(100_000_000))
                await tokens[i].connect(deployer).allocateTo(carol.address, expandTo18Decimals(100_000_000))
                await tokens[i].connect(deployer).allocateTo(deployer.address, expandTo18Decimals(100_000_000))
                await tokens[i].connect(deployer).approve(compound.comet.address, expandTo18Decimals(100_000_000))
                await compound.comet.connect(deployer).supply(tokens[i].address, expandTo18Decimals(1_000_000))

            }
        }
    })

    it('allows regular interactions', async () => {

        const suppIndex = 'USDT'
        const borrowIndex = 'USDC'

        const supplyAmount = expandTo18Decimals(100)
        const borrowAmount = expandTo18Decimals(10)

        await compound.tokens[suppIndex].connect(bob).approve(compound.comet.address, ethers.constants.MaxUint256)

        await compound.comet.connect(bob).supply(compound.tokens[suppIndex].address, supplyAmount)

        const borrow = await compound.comet.isBorrowCollateralized(bob.address)

        await compound.comet.connect(bob).withdraw(compound.tokens[borrowIndex].address, borrowAmount)
    })


})
