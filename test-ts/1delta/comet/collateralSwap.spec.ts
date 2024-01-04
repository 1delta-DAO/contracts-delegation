import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { constants } from 'ethers';
import { ethers } from 'hardhat'
import { MintableERC20, WETH9 } from '../../../types';
import { CompoundV3Protocol, makeProtocol } from '../shared/compoundV3Fixture';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals';
import { CometBrokerFixture, TestConfig1delta, cometBrokerFixture, initCometBroker } from '../shared/cometBrokerFixture.';
import { UniswapMinimalFixtureNoTokens, addLiquidity, addLiquidityV2, uniswapMinimalFixtureNoTokens } from '../shared/uniswapFixture';
import { FeeAmount } from '../../uniswap-v3/periphery/shared/constants';
import { expect } from 'chai';
import { V2Fixture, uniV2Fixture } from '../shared/uniV2Fixture';
import { encodeAggregatorPathEthers } from '../shared/aggregatorPath';


// we prepare a setup for compound in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('CompoundV3 Brokered Collateral Swap operations', async () => {
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
                compound.tokens['WETH'].connect(deployer).deposit({ value: expandTo18Decimals(1_000) })
                await tokens[i].connect(deployer).approve(compound.comet.address, expandTo18Decimals(100_000_000))
                await compound.comet.connect(deployer).supply(tokens[i].address, expandTo18Decimals(1_000))
            } else {
                try {

                    const p = await compound.comet.getAssetInfo(i)
                    const pp = await compound.comet.getPrice(p.priceFeed)
                    console.log("price", pp.toString())
                    console.log(p.borrowCollateralFactor.toString(), p.supplyCap.toString())

                } catch (e) { console.log('added asset') }

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
        }
        await broker.manager.connect(deployer).addComet(compound.comet.address, 0)
        await broker.manager.connect(deployer).approveComet(tokens.map(t => t.address), 0)
        console.log("add liquidity")

        await addLiquidity(
            deployer,
            compound.tokens["DAI"].address,
            compound.tokens["WMATIC"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )


        await addLiquidity(
            deployer,
            compound.tokens["DAI"].address,
            compound.tokens["USDC"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        await addLiquidityV2(
            deployer,
            compound.tokens["DAI"].address,
            compound.tokens["WMATIC"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswapV2
        )

    })


    it('allows collateral swap exact in', async () => {

        const supplyTokenIndex = "DAI"
        const supplyTokenIndexOther = "WMATIC"
        const borrowTokenIndex = "USDC"
        const providedAmount = expandTo18Decimals(50)
        const providedAmountOther = expandTo18Decimals(50)

        const swapAmount = expandTo18Decimals(45)
        const borrowAmount = expandTo18Decimals(70)

        console.log("approve")
        await compound.tokens[supplyTokenIndex].connect(carol).approve(compound.comet.address, constants.MaxUint256)
        await compound.tokens[supplyTokenIndexOther].connect(carol).approve(compound.comet.address, constants.MaxUint256)

        // open first position
        await compound.comet.connect(carol).supply(compound.tokens[supplyTokenIndex].address, providedAmount)

        // open second position
        await compound.comet.connect(carol).supply(compound.tokens[supplyTokenIndexOther].address, providedAmountOther)

        console.log("borrow")
        await compound.comet.connect(carol).withdraw(
            compound.tokens[borrowTokenIndex].address,
            borrowAmount,
        )
        let _tokensInRoute = [
            compound.tokens[supplyTokenIndex],
            compound.tokens[supplyTokenIndexOther]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6], // action
            [5], // pid - V3
            0 // cometId
        )
        const params = {
            path,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(98).div(100),
            cometId: 0
        }

        await compound.tokens[supplyTokenIndex].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)
        await compound.tokens[supplyTokenIndexOther].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)

        await compound.comet.connect(carol).allow(broker.brokerProxy.address, true)

        const cBeforeIn = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndex].address)
        const cBeforeOut = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndexOther].address)

        // swap collateral
        console.log("collateral swap")
        await broker.broker.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)

        const cAfterIn = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndex].address)
        const cAfterOut = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[supplyTokenIndexOther].address)

        expect(cBeforeIn.sub(cAfterIn).toString()).to.equal(swapAmount.toString())
    })

    it('allows collateral swap exact out', async () => {

        const supplyTokenIndex = "DAI"
        const supplyTokenIndexOther = "WMATIC"
        const borrowTokenIndex = "USDC"
        const providedAmount = expandTo18Decimals(50)
        const providedAmountOther = expandTo18Decimals(50)

        const swapAmount = expandTo18Decimals(45)
        const borrowAmount = expandTo18Decimals(70)

        console.log("approve")
        await compound.tokens[supplyTokenIndex].connect(gabi).approve(compound.comet.address, constants.MaxUint256)
        await compound.tokens[supplyTokenIndexOther].connect(gabi).approve(compound.comet.address, constants.MaxUint256)

        // open first position
        await compound.comet.connect(gabi).supply(compound.tokens[supplyTokenIndex].address, providedAmount)

        // open second position
        await compound.comet.connect(gabi).supply(compound.tokens[supplyTokenIndexOther].address, providedAmountOther)

        console.log("borrow")
        await compound.comet.connect(gabi).withdraw(
            compound.tokens[borrowTokenIndex].address,
            borrowAmount,
        )
        let _tokensInRoute = [
            compound.tokens[supplyTokenIndex],
            compound.tokens[supplyTokenIndexOther]
        ].map(t => t.address).reverse()
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [3], // action
            [1], // pid - V3
            0 // cometId
        )

        const params = {
            path,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100),
            cometId: 0
        }
        await compound.tokens[supplyTokenIndex].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)
        await compound.tokens[supplyTokenIndexOther].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)

        const cBeforeIn = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const cBeforeOut = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndexOther].address)

        await compound.comet.connect(gabi).allow(broker.brokerProxy.address, true)
        // swap collateral
        console.log("collateral swap")
        await broker.broker.connect(gabi).flashSwapExactOut(params.amountOut, params.amountInMaximum, params.path)

        const cAfterIn = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndex].address)
        const cAfterOut = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[supplyTokenIndexOther].address)


        expect(cAfterOut.sub(cBeforeOut).toString()).to.equal(swapAmount)
        // console.log("in", Number(formatEther(ctIn)), "bench", Number(formatEther(expandTo18Decimals(5))))
        // expect(Number(formatEther(ctIn))).to.lessThanOrEqual(Number(formatEther(expandTo18Decimals(5))))
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
// |  CometMarginTraderModule             ·  swapCollateralExactIn               ·          -  ·          -  ·   253348  ·            1  ·      23.15  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMarginTraderModule             ·  swapCollateralExactOut              ·          -  ·          -  ·   243868  ·            1  ·      22.28  │
// ·······································|······································|·············|·············|···········|···············|··············

// NEW IMPLEMENTAION
// ·······································|······································|·············|·············|·············|···············|··············
// |  FlashAggregator                     ·  flashSwapExactIn                    ·          -  ·          -  ·     279869  ·            1  ·       8.04  │
// ·······································|······································|·············|·············|·············|···············|··············
// |  FlashAggregator                     ·  flashSwapExactOut                   ·          -  ·          -  ·     234867  ·            1  ·       6.74  │
// ·······································|······································|·············|·············|·············|···············|··············
