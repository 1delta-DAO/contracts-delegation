import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
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
import { V2Fixture, uniV2Fixture } from '../shared/uniV2Fixture';
import { encodeAggregatorPathEthers } from '../shared/aggregatorPath';


// we prepare a setup for compound in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('CompoundV3 Brokered Margin Multi Swap operations', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let test: SignerWithAddress;
    let test0: SignerWithAddress;
    let test1: SignerWithAddress;
    let test2: SignerWithAddress;
    let tokens: (MintableERC20 | WETH9)[];
    let compound: CompoundV3Protocol
    let uniswap: UniswapMinimalFixtureNoTokens;
    let broker: CometBrokerFixture
    let uniswapV2: V2Fixture

    before('Deploy Account, Trader, Uniswap and Compound', async () => {
        [deployer, alice, bob, carol, gabi, test, test1, test2, test0] = await ethers.getSigners();

        compound = await makeProtocol({ base: 'USDC', targetReserves: 0, assets: TestConfig1delta });
        uniswap = await uniswapMinimalFixtureNoTokens(deployer, compound.tokens["WETH"].address)
        uniswapV2 = await uniV2Fixture(deployer, compound.tokens["WETH"].address)
        broker = await cometBrokerFixture(deployer, uniswap.factory.address, uniswapV2.factoryV2.address, compound.tokens["WETH"].address)

        await initCometBroker(deployer, broker, compound.comet.address)


        const tokens = Object.values(compound.tokens)
        const keys = Object.keys(compound.tokens)
        for (let i = 0; i < tokens.length; i++) {
            const key = keys[i]
            console.log(key)
            if (key === 'WETH') {
                compound.tokens['WETH'].connect(deployer).deposit({ value: expandTo18Decimals(2_000) })
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

        console.log("add liquidity DAI WMATIC")
        await addLiquidity(
            deployer,
            compound.tokens["DAI"].address,
            compound.tokens["WMATIC"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity USDC WETH")
        await addLiquidity(
            deployer,
            compound.tokens["USDC"].address,
            compound.tokens["WETH"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(200),
            uniswap
        )

        console.log("add liquidity USDC WMATIC")
        await addLiquidity(
            deployer,
            compound.tokens["USDC"].address,
            compound.tokens["WMATIC"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )


        console.log("add liquidity WETH MATIC")
        await addLiquidity(
            deployer,
            compound.tokens["WETH"].address,
            compound.tokens["WMATIC"].address,
            expandTo18Decimals(200),
            expandTo18Decimals(1_000_000),
            uniswap
        )

    })


    it('allows margin swap multi exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens["WMATIC"],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6, 0], // action
            [0, 0], // pid - V3
            0 // cometId
        )
        const params = {
            path,
            userAmountProvided: providedAmount,
            cometId: 0,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(99).div(100)
        }

        await compound.comet.connect(carol).supply(compound.tokens[supplyTokenIndex].address, providedAmount)

        await compound.tokens[supplyTokenIndex].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)
        await compound.tokens["USDC"].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)


        await compound.tokens[supplyTokenIndex].connect(carol).approve(compound.comet.address, constants.MaxUint256)

        await compound.comet.connect(carol).supply(compound.tokens[supplyTokenIndex].address, 100,)

        const cBefore = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const dBefore = await compound.comet.borrowBalanceOf(gabi.address)

        await compound.comet.connect(carol).allow(broker.brokerProxy.address, true)
        await broker.broker.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)


        const cAfter = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndex].address)
        const dAfter = await compound.comet.borrowBalanceOf(carol.address)
        expect(dAfter.sub(dBefore).toString()).to.equal(swapAmount)
    })

    it('respects slippage - multi exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"
        const providedAmount = expandTo18Decimals(50)

        const swapAmount = expandTo18Decimals(95)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens["WMATIC"],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6, 0], // action
            [0, 0], // pid - V3
            0 // cometId
        )
        const params = {
            path,
            userAmountProvided: providedAmount,
            cometId: 0,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(101).div(100)
        }

        await compound.comet.connect(carol).allow(broker.brokerProxy.address, true)

        await expect(broker.broker.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)).to.be.revertedWith('Slippage()')

    })

    it('allows margin swap multi exact out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens["WMATIC"],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // reverse path for exact out
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [3, 1], // action
            [0, 0], // pid - V3
            0 // cometId
        )
        const params = {
            path,
            userAmountProvided: providedAmount,
            cometId: 0,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(105).div(100)
        }
        await compound.comet.connect(gabi).supply(compound.tokens[supplyTokenIndex].address, providedAmount)


        await compound.tokens[borrowTokenIndex].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)
        await compound.tokens[supplyTokenIndex].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)
        await compound.tokens["USDC"].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)


        await compound.tokens[supplyTokenIndex].connect(gabi).approve(compound.comet.address, constants.MaxUint256)

        await compound.comet.connect(gabi).supply(compound.tokens[supplyTokenIndex].address, 100,)

        await compound.comet.connect(gabi).allow(broker.brokerProxy.address, true)

        await broker.broker.connect(gabi).flashSwapExactOut(params.amountOut, params.amountInMaximum, params.path)

        const cAfter = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const dAfter = await compound.comet.borrowBalanceOf(gabi.address)
        expect(cAfter.toString()).to.equal(swapAmount.add(providedAmount).add(100).toString())
    })

    it('respects slippage - multi exact out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"
        const providedAmount = expandTo18Decimals(50)

        const swapAmount = expandTo18Decimals(95)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens["WMATIC"],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // reverse path for exact out
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [3, 1], // action
            [0, 0], // pid - V3
            0 // cometId
        )
        const params = {
            path,
            userAmountProvided: providedAmount,
            cometId: 0,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(99).div(100)
        }

        await compound.comet.connect(gabi).allow(broker.brokerProxy.address, true)
        await expect(broker.broker.connect(gabi).flashSwapExactOut(params.amountOut, params.amountInMaximum, params.path)).to.be.revertedWith('Slippage()')
    })



    it('allows trimming margin position exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"

        const swapAmount = expandTo18Decimals(900)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens["WMATIC"],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // for trimming, we have to revert the swap path
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6, 0], // action
            [0, 0], // pid - V3
            0 // cometId
        )

        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            cometId: 0,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(99).div(100)
        }


        const cBefore = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndex].address)
        const dBefore = await compound.comet.borrowBalanceOf(carol.address)

        await compound.comet.connect(carol).allow(broker.brokerProxy.address, true)
        // open margin position
        await broker.broker.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)

        const cAfter = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndex].address)
        const dAfter = await compound.comet.borrowBalanceOf(carol.address)

        expect(Number(formatEther(dAfter))).to.be.
            lessThanOrEqual(Number(formatEther(dBefore.sub(swapAmount))) * 1.05)

        expect(Number(formatEther(dAfter))).to.be.
            greaterThanOrEqual(Number(formatEther(dBefore.sub(swapAmount))))


        expect(Number(formatEther(cAfter))).to.be.
            greaterThanOrEqual(Number(formatEther(cBefore.sub(swapAmount))))

        expect(Number(formatEther(cAfter))).to.be.
            lessThanOrEqual(Number(formatEther(cBefore.sub(swapAmount))) * 1.001)
    })


    it('allows trimming margin position exact out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "USDC"

        const swapAmount = expandTo18Decimals(900)

        let _tokensInRoute = [
            compound.tokens[borrowTokenIndex],
            compound.tokens["WMATIC"],
            compound.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [3, 1], // action
            [0, 0], // pid - V3
            0 // cometId
        )
        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            amountInMaximum: swapAmount.mul(102).div(100),
            amountOut: swapAmount,
            cometId: 0,
        }
        const cBefore = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const dBefore = await compound.comet.borrowBalanceOf(gabi.address)

        await compound.comet.connect(gabi).allow(broker.brokerProxy.address, true)
        // trim margin position
        await broker.broker.connect(gabi).flashSwapExactOut(params.amountOut, params.amountInMaximum, params.path)

        const cAfter = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const dAfter = await compound.comet.borrowBalanceOf(gabi.address)


        expect(Number(formatEther(dAfter))).to.be.
            lessThanOrEqual(Number(formatEther(dBefore.sub(swapAmount))) * 1.005)

        expect(Number(formatEther(dAfter))).to.be.
            greaterThanOrEqual(Number(formatEther(dBefore.sub(swapAmount))))


        expect(Number(formatEther(cAfter))).to.be.
            lessThan(Number(formatEther(cBefore.sub(swapAmount))) * 1.005)

        expect(Number(formatEther(cAfter))).to.be.
            greaterThan(Number(formatEther(cBefore.sub(swapAmount))) * 0.99)
    })

})

// ·----------------------------------------------------------------------------------------------|---------------------------|-----------------|-----------------------------·
// |                                     Solc version: 0.8.23                                     ·  Optimizer enabled: true  ·  Runs: 1000000  ·  Block limit: 30000000 gas  │
// ·······························································································|···························|·················|······························
// |  Methods                                                                                                                                                                 │
// ························································|······································|·············|·············|·················|···············|··············
// |  Contract                                             ·  Method                              ·  Min        ·  Max        ·  Avg            ·  # calls      ·  usd (avg)  │
// ························································|······································|·············|·············|·················|···············|··············
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  openMarginPositionExactIn           ·          -  ·          -  ·   340699  ·            1  ·      15.45  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  openMarginPositionExactOut          ·          -  ·          -  ·   293332  ·            1  ·      13.31  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  trimMarginPositionExactIn           ·          -  ·          -  ·   333622  ·            1  ·      15.13  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  trimMarginPositionExactOut          ·          -  ·          -  ·   292254  ·            1  ·      13.26  │
// ·······································|······································|·············|·············|···········|···············|··············
//  NEW IMPLEMNENTATION
// ·······································|······································|·············|·············|·············|···············|··············
// |  FlashAggregator                     ·  flashSwapExactIn                    ·     319250  ·     337712  ·     328481  ·            2  ·       8.84  │
// ·······································|······································|·············|·············|·············|···············|··············
// |  FlashAggregator                     ·  flashSwapExactOut                   ·     277692  ·     281128  ·     279410  ·            2  ·       7.52  │
// ·······································|······································|·············|·············|·············|···············|··············
