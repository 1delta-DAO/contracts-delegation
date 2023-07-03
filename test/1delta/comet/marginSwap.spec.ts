import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { constants } from 'ethers';
import { formatEther } from 'ethers/lib/utils';
import { ethers, network } from 'hardhat'
import { MintableERC20, WETH9 } from '../../../types';
import { CompoundV3Protocol, makeProtocol } from '../shared/compoundV3Fixture';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals';
import { CometBrokerFixture, TestConfig1delta, cometBrokerFixture, initCometBroker } from '../shared/cometBrokerFixture.';
import { UniswapMinimalFixtureNoTokens, addLiquidity, uniswapMinimalFixtureNoTokens } from '../shared/uniswapFixture';
import { FeeAmount } from '../../uniswap-v3/periphery/shared/constants';
import { expect } from 'chai';
import { encodePath } from '../../uniswap-v3/periphery/shared/path';


// we prepare a setup for compound in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('CompoundV3 Brokered Margin Swap operations', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let test: SignerWithAddress;
    let test1: SignerWithAddress;
    let test2: SignerWithAddress;
    let tokens: (MintableERC20 | WETH9)[];
    let compound: CompoundV3Protocol
    let uniswap: UniswapMinimalFixtureNoTokens;
    let broker: CometBrokerFixture

    before('Deploy Account, Trader, Uniswap and Compound', async () => {
        [deployer, alice, bob, carol, gabi, test, test1, test2] = await ethers.getSigners();

        compound = await makeProtocol({ base: 'USDC', targetReserves: 0, assets: TestConfig1delta });
        uniswap = await uniswapMinimalFixtureNoTokens(deployer, compound.tokens["WETH"].address)
        broker = await cometBrokerFixture(deployer, uniswap.factory.address)

        await initCometBroker(deployer, broker, uniswap, compound)
        await broker.manager.setUniswapRouter(uniswap.router.address)

        const tokens = Object.values(compound.tokens)
        const keys = Object.keys(compound.tokens)
        for (let i = 0; i < tokens.length; i++) {
            const key = keys[i]
            console.log(key)
            if (key === 'WETH') {
                compound.tokens['WETH'].connect(deployer).deposit({ value: expandTo18Decimals(1_000) })
                await tokens[i].connect(deployer).approve(compound.comet.address, expandTo18Decimals(100_000_000))
                await compound.comet.connect(deployer).supply(tokens[i].address, expandTo18Decimals(1_000))
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
                await tokens[i].connect(deployer).allocateTo(gabi.address, expandTo18Decimals(100_000_000))
                await tokens[i].connect(deployer).approve(compound.comet.address, expandTo18Decimals(100_000_000))
                await compound.comet.connect(deployer).supply(tokens[i].address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(bob).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(alice).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(carol).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(test).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(test1).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(test2).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(gabi).approve(compound.comet.address, ethers.constants.MaxUint256)
            }


            const token = compound.tokens[key]
            await token.connect(deployer).approve(uniswap.router.address, constants.MaxUint256)
            await token.connect(bob).approve(uniswap.router.address, constants.MaxUint256)
            await token.connect(carol).approve(uniswap.router.address, constants.MaxUint256)
            await token.connect(alice).approve(uniswap.router.address, constants.MaxUint256)
            await token.approve(uniswap.router.address, constants.MaxUint256)
            await token.approve(uniswap.nft.address, constants.MaxUint256)

            await token.connect(bob).approve(uniswap.router.address, constants.MaxUint256)
            await token.connect(bob).approve(uniswap.nft.address, constants.MaxUint256)
            await token.connect(alice).approve(uniswap.router.address, constants.MaxUint256)
            await token.connect(alice).approve(uniswap.nft.address, constants.MaxUint256)
            await token.connect(carol).approve(uniswap.router.address, constants.MaxUint256)
            await token.connect(carol).approve(uniswap.nft.address, constants.MaxUint256)

            await token.connect(bob).approve(uniswap.router.address, constants.MaxUint256)
            await token.connect(alice).approve(uniswap.router.address, constants.MaxUint256)
            await token.connect(carol).approve(uniswap.router.address, constants.MaxUint256)

        }
        await broker.manager.connect(deployer).approveComet(tokens.map(t => t.address), 0)
        await broker.manager.connect(deployer).addComet(compound.comet.address, 0)
        console.log("add liquidity")

        await addLiquidity(
            deployer,
            compound.tokens["DAI"].address,
            compound.tokens["USDC"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )
    })


    it('allows margin swap exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            userAmountProvided: providedAmount,
           cometId:0,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(99).div(100)
        }

        await compound.tokens[borrowTokenIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)
        await compound.tokens[supplyTokenIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)


        await compound.tokens[supplyTokenIndex].connect(carol).approve(compound.comet.address, constants.MaxUint256)

        // supply collateral, allow delegation

        await compound.comet.connect(carol).supply(compound.tokens[supplyTokenIndex].address, providedAmount)
        await compound.comet.connect(carol).allow(broker.broker.address, true)


        const cBefore = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndex].address)
        const dBefore = await compound.comet.borrowBalanceOf(carol.address)

        // open margin position
        await broker.broker.connect(carol).openMarginPositionExactIn(params)

        const cAfter = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndex].address)
        const dAfter = await compound.comet.borrowBalanceOf(carol.address)
        expect(dAfter.sub(dBefore).toString()).to.equal(swapAmount.toString())

        expect(Number(formatEther(cAfter.sub(cBefore)))).to.be.
            lessThanOrEqual(Number(formatEther((swapAmount))))

        expect(Number(formatEther(cAfter.sub(cBefore)))).to.be.
            greaterThanOrEqual(Number(formatEther((swapAmount))) * 0.95)
    })


    it('allows margin swap exact out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        await compound.tokens[borrowTokenIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)
        await compound.tokens[supplyTokenIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)


        await compound.tokens[supplyTokenIndex].connect(gabi).approve(compound.comet.address, constants.MaxUint256)

        // supply collateral, allow delegation

        await compound.comet.connect(gabi).supply(compound.tokens[supplyTokenIndex].address, providedAmount)
        await compound.comet.connect(gabi).allow(broker.broker.address, true)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address)

        // reverse path for exact out
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            userAmountProvided: providedAmount,
           cometId:0,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(105).div(100)
        }


        const cBefore = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const dBefore = await compound.comet.borrowBalanceOf(gabi.address)

        // open margin position
        await broker.broker.connect(gabi).openMarginPositionExactOut(params)

        const cAfter = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const dAfter = await compound.comet.borrowBalanceOf(gabi.address)
        expect(cAfter.sub(cBefore).toString()).to.equal(swapAmount.toString())

        expect(Number(formatEther(dAfter.sub(dBefore)))).to.be.
            lessThanOrEqual(Number(formatEther((swapAmount))) * 1.009)

        expect(Number(formatEther(dAfter.sub(dBefore)))).to.be.
            greaterThanOrEqual(Number(formatEther((swapAmount))))

    })


    it('allows trimming margin position exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"

        const swapAmount = expandTo18Decimals(900)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address)

        // for trimming, we have to revert the swap path
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))


        const params = {
            path,
            fee: FeeAmount.MEDIUM,
           cometId:0,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(99).div(100)
        }



        const cBefore = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndex].address)
        const dBefore = await compound.comet.borrowBalanceOf(carol.address)
        // open margin position
        await broker.broker.connect(carol).trimMarginPositionExactIn(params)

        const cAfter = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndex].address)
        const dAfter = await compound.comet.borrowBalanceOf(carol.address)

        expect(Number(formatEther(dBefore.sub(dAfter)))).to.be.
            lessThanOrEqual(Number(formatEther((swapAmount))))

        expect(Number(formatEther(dBefore.sub(dAfter)))).to.be.
            greaterThanOrEqual(Number(formatEther((swapAmount))) * 0.995)

        expect(Number(formatEther(cBefore.sub(cAfter)))).to.be.
            lessThanOrEqual(Number(formatEther((swapAmount))) * 1.005)

        expect(Number(formatEther(cBefore.sub(cAfter)))).to.be.
            greaterThanOrEqual(Number(formatEther((swapAmount))))
    })



    it('allows trimming margin position exact out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"

        const swapAmount = expandTo18Decimals(900)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            amountInMaximum: swapAmount.mul(102).div(100),
            amountOut: swapAmount,
           cometId:0,
        }
        const cBefore = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const dBefore = await compound.comet.borrowBalanceOf(gabi.address)
        // trim margin position
        await broker.broker.connect(gabi).trimMarginPositionExactOut(params)

        const cAfter = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const dAfter = await compound.comet.borrowBalanceOf(gabi.address)

        expect(Number(formatEther(dAfter))).to.be.
            lessThanOrEqual(Number(formatEther(dBefore.sub(swapAmount))) * 1.005)

        expect(Number(formatEther(dAfter))).to.be.
            greaterThanOrEqual(Number(formatEther(dBefore.sub(swapAmount))))


        expect(Number(formatEther(cAfter))).to.be.
            lessThan(Number(formatEther(cBefore.sub(swapAmount))) * 1.005)

        expect(Number(formatEther(cAfter))).to.be.
            greaterThan(Number(formatEther(cBefore.sub(swapAmount))) * 0.995)
    })



})

// ·-----------------------------------------------------------------------------|---------------------------|-----------|-----------------------------·
// |                            Solc version: 0.8.15                             ·  Optimizer enabled: true  ·  Runs: 1  ·  Block limit: 30000000 gas  │
// ··············································································|···························|···········|······························
// |  Methods                                                                                                                                          │
// ·······································|······································|·············|·············|···········|···············|··············
// |  Contract                            ·  Method                              ·  Min        ·  Max        ·  Avg      ·  # calls      ·  usd (avg)  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  openMarginPositionExactIn           ·          -  ·          -  ·   249469  ·            1  ·      12.27  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  openMarginPositionExactOut          ·          -  ·          -  ·   225215  ·            1  ·      11.07  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  trimMarginPositionExactIn           ·          -  ·          -  ·   241616  ·            1  ·      11.88  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  trimMarginPositionExactOut          ·          -  ·          -  ·   225448  ·            1  ·      11.08  │
// ·······································|······································|·············|·············|···········|···············|··············
