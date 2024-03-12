import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { ethers, network, waffle } from 'hardhat'
import {
    MintableERC20,
    WETH9
} from '../../../types';
import { FeeAmount } from '../../uniswap-v3/periphery/shared/constants';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals';
import { ONE_18, AaveBrokerFixtureInclV2, aaveBrokerFixtureInclV2, initAaveBroker } from '../shared/aaveBrokerFixture';
import { expect } from '../shared/expect'
import { initializeMakeSuite, InterestRateMode, AAVEFixture, deposit } from '../shared/aaveFixture';
import { addLiquidity, addLiquidityV2, uniswapMinimalFixtureNoTokens, UniswapMinimalFixtureNoTokens } from '../shared/uniswapFixture';
import { formatEther } from 'ethers/lib/utils';
import { uniV2Fixture, V2Fixture } from '../shared/uniV2Fixture';
import { encodeAggregatorPathEthers, encodeTradePathMargin, TradeOperation, TradeType } from '../shared/aggregatorPath';

// we prepare a setup for aave in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('AAVE Brokered Margin Multi Swap operations', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let test: SignerWithAddress;
    let test1: SignerWithAddress;
    let test2: SignerWithAddress;
    let test3: SignerWithAddress;
    let uniswap: UniswapMinimalFixtureNoTokens;
    let aaveTest: AAVEFixture;
    let broker: AaveBrokerFixtureInclV2;
    let tokens: (MintableERC20 | WETH9)[];
    let provider: MockProvider
    let uniswapV2: V2Fixture


    before('Deploy Account, Trader, Uniswap and AAVE', async () => {
        [deployer, alice, bob, carol, gabi, test, test1, test2, test3] = await ethers.getSigners();


        provider = waffle.provider;

        aaveTest = await initializeMakeSuite(deployer, 1, true)
        tokens = Object.values(aaveTest.tokens)
        uniswap = await uniswapMinimalFixtureNoTokens(deployer, aaveTest.tokens["WETH"].address)
        uniswapV2 = await uniV2Fixture(deployer, aaveTest.tokens["WETH"].address)
        broker = await aaveBrokerFixtureInclV2(deployer, uniswap.factory.address, aaveTest.pool.address, uniswapV2.factoryV2.address, aaveTest.tokens["WETH"].address)

        await initAaveBroker(deployer, broker as any, aaveTest.pool.address)

        // approve & fund wallets
        let keys = Object.keys(aaveTest.tokens)
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i]
            await aaveTest.tokens[key].connect(deployer).approve(aaveTest.pool.address, constants.MaxUint256)
            if (key === "WETH") {
                await (aaveTest.tokens[key] as WETH9).deposit({ value: expandTo18Decimals(2_000) })
                await aaveTest.pool.connect(deployer).supply(aaveTest.tokens[key].address, expandTo18Decimals(1_000), deployer.address, 0)

            } else {
                await (aaveTest.tokens[key] as MintableERC20)['mint(address,uint256)'](deployer.address, expandTo18Decimals(100_000_000))
                await aaveTest.pool.connect(deployer).supply(aaveTest.tokens[key].address, expandTo18Decimals(10_000), deployer.address, 0)

                await aaveTest.tokens[key].connect(deployer).transfer(bob.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(alice.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(carol.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test1.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test2.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test3.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(gabi.address, expandTo18Decimals(1_000_000))

                await aaveTest.tokens[key].connect(bob).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(alice).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(carol).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test1).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test2).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test3).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(gabi).approve(aaveTest.pool.address, ethers.constants.MaxUint256)

            }

            const token = aaveTest.tokens[key]
            await broker.manager.addAToken(token.address, aaveTest.aTokens[key].address)
            await broker.manager.addSToken(token.address, aaveTest.sTokens[key].address)
            await broker.manager.addVToken(token.address, aaveTest.vTokens[key].address)

        }

        await broker.manager.connect(deployer).approveAddress(tokens.map(t => t.address), aaveTest.pool.address)

        console.log("add liquidity DAI USDC")
        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["USDC"].address,
            expandTo18Decimals(100_000),
            BigNumber.from(100_000e6), // usdc has 6 decimals
            uniswap
        )
        console.log("add liquidity DAI AAVE")
        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["AAVE"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity AAVE WETH")
        await addLiquidity(
            deployer,
            aaveTest.tokens["AAVE"].address,
            aaveTest.tokens["WETH"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(200),
            uniswap
        )

        console.log("add liquidity AAVE WMATIC")
        await addLiquidity(
            deployer,
            aaveTest.tokens["AAVE"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity WETH MATIC")
        await addLiquidity(
            deployer,
            aaveTest.tokens["WETH"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(200),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity DAI CRV")
        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["CRV"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        // V2
        console.log("add liquidity V2 DAI USDC")
        await addLiquidityV2(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["USDC"].address,
            expandTo18Decimals(100_000),
            BigNumber.from(100_000e6), // usdc has 6 decimals
            uniswapV2
        )
        console.log("add liquidity V2 DAI AAVE")
        await addLiquidityV2(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["AAVE"].address,
            expandTo18Decimals(10_000_000),
            expandTo18Decimals(10_000_000),
            uniswapV2
        )

        console.log("add liquidity V2 AAVE WETH")
        await addLiquidityV2(
            deployer,
            aaveTest.tokens["AAVE"].address,
            aaveTest.tokens["WETH"].address,
            expandTo18Decimals(10_000_000),
            expandTo18Decimals(200),
            uniswapV2
        )

        console.log("add liquidity V2 AAVE WMATIC")
        await addLiquidityV2(
            deployer,
            aaveTest.tokens["AAVE"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(10_000_000),
            expandTo18Decimals(10_000_000),
            uniswapV2
        )

        console.log("add liquidity V2 WETH MATIC")
        await addLiquidityV2(
            deployer,
            aaveTest.tokens["WETH"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(200),
            expandTo18Decimals(10_000_000),
            uniswapV2
        )

        console.log("add liquidity V2 DAI CRV")
        await addLiquidityV2(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["CRV"].address,
            expandTo18Decimals(10_000_000),
            expandTo18Decimals(10_000_000),
            uniswapV2
        )
    })

    // checks that the aave protocol is set up correctly, i.e. borrowing and supply works
    it('deploys everything', async () => {
        await aaveTest.aDai.symbol()
        const { WETH, DAI } = aaveTest.tokens
        await (DAI as MintableERC20).connect(bob)['mint(address,uint256)'](bob.address, ONE_18.mul(1_000))
        await DAI.connect(bob).approve(aaveTest.pool.address, constants.MaxUint256)

        // supply and borrow
        await aaveTest.pool.connect(bob).supply(DAI.address, ONE_18.mul(10), bob.address, 0)
        await aaveTest.pool.connect(bob).setUserUseReserveAsCollateral(DAI.address, true)
        await aaveTest.pool.connect(bob).borrow(WETH.address, ONE_18, InterestRateMode.VARIABLE, 0, bob.address)
    })


    it('allows margin swap multi exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "WMATIC"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6, 0], // action
            [8, 91], // pid - V3
            2 // flag - borrow variable
        )

        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(99).div(100)
        }
        await deposit(aaveTest, supplyTokenIndex, carol, providedAmount)

        await aaveTest.tokens[supplyTokenIndex].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.tokens["AAVE"].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(carol).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.tokens[supplyTokenIndex].connect(carol).approve(aaveTest.pool.address, constants.MaxUint256)

        await aaveTest.pool.connect(carol).supply(aaveTest.tokens[supplyTokenIndex].address, 100, carol.address, 0)
        await aaveTest.pool.connect(carol).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        await broker.trader.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)

        const bb = await aaveTest.pool.getUserAccountData(carol.address)
        expect(bb.totalDebtBase.toString()).to.equal(swapAmount)
    })

    it('allows margin swap multi exact in 3-hop', async () => {

        const supplyTokenIndex = "CRV"
        const borrowTokenIndex = "WMATIC"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["DAI"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6, 0, 0], // action
            [8, 91, 9], // pid - V3
            2 // flag - borrow variable
        )

        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(97).div(100)
        }
        await deposit(aaveTest, supplyTokenIndex, carol, providedAmount)

        await aaveTest.tokens[supplyTokenIndex].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.tokens["AAVE"].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(carol).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.tokens[supplyTokenIndex].connect(carol).approve(aaveTest.pool.address, constants.MaxUint256)

        await aaveTest.pool.connect(carol).supply(aaveTest.tokens[supplyTokenIndex].address, 100, carol.address, 0)
        await aaveTest.pool.connect(carol).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)
        const bbefore = await aaveTest.vTokens[borrowTokenIndex].balanceOf(carol.address)
        await broker.trader.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)

        const bb = await aaveTest.vTokens[borrowTokenIndex].balanceOf(carol.address)
        expect(bb.sub(bbefore).toString()).to.equal(swapAmount)
    })


    it('respects slippage - multi exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "WMATIC"
        const providedAmount = expandTo18Decimals(50)

        const swapAmount = expandTo18Decimals(95)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6, 0], // action
            [55, 59], // pid - V3
            2 // flag - borrow variable
        )
        const params = {
            path,
            userAmountProvided: providedAmount,
            interestRateMode: InterestRateMode.VARIABLE,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(105).div(100)
        }

        await expect(broker.trader.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)).to.be.revertedWith('Slippage()')

    })

    it('allows margin swap multi exact out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "WMATIC"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // reverse path for exact out
        const path = encodeTradePathMargin(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [1, 2],
            TradeOperation.Open,
            TradeType.exactOut,
            InterestRateMode.VARIABLE,
            InterestRateMode.VARIABLE
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(105).div(100)
        }

        await deposit(aaveTest, supplyTokenIndex, gabi, providedAmount)

        await aaveTest.tokens[borrowTokenIndex].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndex].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.tokens["AAVE"].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(gabi).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.tokens[supplyTokenIndex].connect(gabi).approve(aaveTest.pool.address, constants.MaxUint256)

        await aaveTest.pool.connect(gabi).supply(aaveTest.tokens[supplyTokenIndex].address, 100, gabi.address, 0)

        await aaveTest.pool.connect(gabi).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        await broker.trader.connect(gabi).flashSwapExactOut(params.amountOut, params.amountInMaximum, params.path)
        const bb = await aaveTest.pool.getUserAccountData(gabi.address)
        expect(bb.totalCollateralBase.toString()).to.equal(swapAmount.add(providedAmount).add(100).toString())
    })

    it('allows margin swap multi exact out 3-hop', async () => {

        const supplyTokenIndex = "CRV"
        const borrowTokenIndex = "WMATIC"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["DAI"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // reverse path for exact out
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [3, 1, 1], // action
            [1, 2, 1], // pid
            2 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(105).div(100)
        }

        await deposit(aaveTest, supplyTokenIndex, gabi, providedAmount)

        await aaveTest.tokens[supplyTokenIndex].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(gabi).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.tokens[supplyTokenIndex].connect(gabi).approve(aaveTest.pool.address, constants.MaxUint256)

        await aaveTest.pool.connect(gabi).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)
        const preCollat = await aaveTest.aTokens[supplyTokenIndex].balanceOf(gabi.address)
        await broker.trader.connect(gabi).flashSwapExactOut(params.amountOut, params.amountInMaximum, params.path)
        const bb = await aaveTest.pool.getUserAccountData(gabi.address)
        const postCollat = await aaveTest.aTokens[supplyTokenIndex].balanceOf(gabi.address)
        expect(postCollat.sub(preCollat).toString()).to.equal(swapAmount.toString())
    })

    it('respects slippage - multi exact out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "WMATIC"
        const providedAmount = expandTo18Decimals(50)

        const swapAmount = expandTo18Decimals(95)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // reverse path for exact out
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [3, 1], // action
            [21, 99], // pid
            2 // flag
        )
        const params = {
            path,
            userAmountProvided: providedAmount,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(95).div(100)
        }
        await expect(broker.trader.connect(gabi).flashSwapExactOut(params.amountOut, params.amountInMaximum, params.path)).to.be.revertedWith('Slippage()')
    })



    it('allows trimming margin position exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "WMATIC"

        const swapAmount = expandTo18Decimals(900)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // for trimming, we have to revert the swap path
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [8, 0], // action
            [1, 10], // pid
            3 // flag
        )

        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            interestRateMode: InterestRateMode.VARIABLE,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(99).div(100)
        }

        await aaveTest.aTokens[supplyTokenIndex].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndex].connect(carol).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        const bBefore = await aaveTest.pool.getUserAccountData(carol.address)

        const debtBefore = await aaveTest.vTokens[borrowTokenIndex].balanceOf(carol.address)
        // close margin position
        await broker.trader.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)
        const bAfter = await aaveTest.pool.getUserAccountData(carol.address)
        const debtAfter = await aaveTest.vTokens[borrowTokenIndex].balanceOf(carol.address)
        expect(Number(formatEther(debtAfter.sub(debtBefore)))).to.be.
            lessThanOrEqual(Number(formatEther(swapAmount)) * 1.05)

        expect(Number(formatEther(debtAfter))).to.be.
            greaterThanOrEqual(Number(formatEther(debtBefore.sub(swapAmount))) * 0.99)


        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            greaterThanOrEqual(Number(formatEther(bBefore.totalCollateralBase.sub(swapAmount))))

        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            lessThanOrEqual(Number(formatEther(bBefore.totalCollateralBase.sub(swapAmount))) * 1.001)
    })

    it('allows trimming margin position all in', async () => {

        const supplyTokenIndex = "DAI"
        const supplyTokenOtherIndex = "AAVE"
        const borrowTokenIndex = "WMATIC"

        const supply = expandTo18Decimals(50)
        const supplyOther = expandTo18Decimals(40)
        const borrow = expandTo18Decimals(60)


        // set up scenario
        await aaveTest.pool.connect(test1).supply(aaveTest.tokens[supplyTokenIndex].address, supply, test1.address, 0)
        await aaveTest.pool.connect(test1).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        await aaveTest.pool.connect(test1).supply(aaveTest.tokens[supplyTokenOtherIndex].address, supplyOther, test1.address, 0)
        await aaveTest.pool.connect(test1).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenOtherIndex].address, true)

        await aaveTest.pool.connect(test1).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrow,
            InterestRateMode.VARIABLE,
            0,
            test1.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // for trimming, we have to revert the swap path
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [8, 0], // action
            [1, 88], // pid
            3 // flag
        )

        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOutMinimum: supply.mul(95).div(100)
        }

        await aaveTest.aTokens[supplyTokenIndex].connect(test1).approve(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndex].connect(test1).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        const bBefore = await aaveTest.pool.getUserAccountData(test1.address)

        // increase ime to make sure that interest accrues
        await network.provider.send("evm_increaseTime", [3600])
        await network.provider.send("evm_mine")

        // open margin position

        await broker.trader.connect(test1).flashSwapAllIn(params.amountOutMinimum, params.path)

        const balanceSupply = await aaveTest.aTokens[supplyTokenIndex].balanceOf(test1.address)

        const bAfter = await aaveTest.pool.getUserAccountData(test1.address)
        expect(Number(formatEther(balanceSupply))).to.eq(0)

        expect(Number(formatEther(bAfter.totalDebtBase))).to.be.
            greaterThanOrEqual(Number(formatEther(bBefore.totalDebtBase.sub(supply))))


        expect(Number(formatEther(bAfter.totalDebtBase))).to.be.
            lessThanOrEqual(Number(formatEther(bBefore.totalDebtBase.sub(supply))) * 1.05)

    })

    it('allows trimming margin position exact out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "WMATIC"

        const swapAmount = expandTo18Decimals(900)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [5, 1], // action
            [1, 88], // pid
            3 // flag
        )
        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            amountInMaximum: swapAmount.mul(102).div(100),
            amountOut: swapAmount,
            interestRateMode: InterestRateMode.VARIABLE,
        }

        await aaveTest.aTokens[supplyTokenIndex].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndex].connect(gabi).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        const bBefore = await aaveTest.pool.getUserAccountData(gabi.address)

        const debtBefore = await aaveTest.vTokens[borrowTokenIndex].balanceOf(gabi.address)
        // trim margin position
        await broker.trader.connect(gabi).flashSwapExactOut(params.amountOut, params.amountInMaximum, params.path)

        const debtAfter = await aaveTest.vTokens[borrowTokenIndex].balanceOf(gabi.address)
        const bAfter = await aaveTest.pool.getUserAccountData(gabi.address)

        expect(Number(formatEther(debtAfter))).to.be.
            lessThanOrEqual(Number(formatEther(debtBefore.sub(swapAmount))) * 1.005)

        expect(Number(formatEther(debtAfter))).to.be.
            greaterThanOrEqual(Number(formatEther(debtBefore.sub(swapAmount))))


        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            lessThan(Number(formatEther(bBefore.totalCollateralBase.sub(swapAmount))) * 1.005)

        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            greaterThan(Number(formatEther(bBefore.totalCollateralBase.sub(swapAmount))) * 0.95)
    })


    it('allows trimming margin position All out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "WMATIC"

        const supply = expandTo18Decimals(900)
        const borrow = expandTo18Decimals(600)


        // set up scenario
        await aaveTest.pool.connect(test).supply(aaveTest.tokens[supplyTokenIndex].address, supply, test.address, 0)
        await aaveTest.pool.connect(test).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)
        await aaveTest.pool.connect(test).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrow,
            InterestRateMode.VARIABLE,
            0,
            test.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [5, 1], // action
            [1, 99], // pid
            3 // flag
        )
        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            amountInMaximum: borrow.mul(105).div(100),
            interestRateMode: InterestRateMode.VARIABLE,
        }

        await aaveTest.aTokens[supplyTokenIndex].connect(test).approve(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndex].connect(test).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        const bBefore = await aaveTest.pool.getUserAccountData(test.address)

        // increase ime to make sure that interest accrues
        await network.provider.send("evm_increaseTime", [3600])
        await network.provider.send("evm_mine")

        // trim margin position
        await broker.trader.connect(test).flashSwapAllOut(params.amountInMaximum, params.path)

        const bAfter = await aaveTest.pool.getUserAccountData(test.address)

        expect(Number(formatEther(bAfter.totalDebtBase))).to.eq(0)


        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            lessThan(Number(formatEther(bBefore.totalCollateralBase.sub(borrow))) * 1.005)

        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            greaterThan(Number(formatEther(bBefore.totalCollateralBase.sub(borrow))) * 0.95)
    })

})

// ·----------------------------------------------------------------------------------------------|---------------------------|-----------------|-----------------------------·
// |                                     Solc version: 0.8.24                                     ·  Optimizer enabled: true  ·  Runs: 1000000  ·  Block limit: 30000000 gas  │
// ·······························································································|···························|·················|······························
// |  Methods                                                                                                                                                                 │
// ························································|······································|·············|·············|·················|···············|··············
// |  Contract                                             ·  Method                              ·  Min        ·  Max        ·  Avg            ·  # calls      ·  usd (avg)  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  openMarginPositionExactIn           ·          -  ·          -  ·   541648  ·            1  ·      15.37  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  openMarginPositionExactOut          ·          -  ·          -  ·   478974  ·            1  ·      13.59  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  trimMarginPositionExactIn           ·          -  ·          -  ·   543764  ·            1  ·      15.43  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  trimMarginPositionExactOut          ·          -  ·          -  ·   482353  ·            1  ·      13.68  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  trimMarginPositionAllIn             ·          -  ·          -  ·   521240  ·            1  ·      14.79  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  trimMarginPositionAllOut            ·          -  ·          -  ·   472541  ·            1  ·      13.41  │
// ························································|······································|·············|·············|···········|···············|··············


// ··············································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                                        ·  flashSwapAllIn                           ·          -  ·          -  ·     500104  ·            1  ·      16.55  │
// ························································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                                        ·  swapAllOut                          ·          -  ·          -  ·     462905  ·            1  ·      15.32  │
// ························································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                                        ·  flashSwapExactIn                         ·     505647  ·     550295  ·     527971  ·            2  ·      17.47  │
// ························································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                                        ·  flashSwapExactOut                        ·     503799  ·     524412  ·     514106  ·            2  ·      17.01  │
// ························································|······································|·············|·············|·············|···············|··············

// ························································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                                        ·  flashSwapAllIn                           ·          -  ·          -  ·     535375  ·            1  ·      49.51  │
// ························································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                                        ·  swapAllOut                          ·          -  ·          -  ·     455943  ·            1  ·      42.16  │
// ························································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                                        ·  flashSwapExactIn                         ·     551688  ·     564411  ·     557690  ·            3  ·      51.57  │
// ························································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                                        ·  flashSwapExactOut                        ·     474192  ·     493775  ·     483984  ·            2  ·      44.75  │
// ························································|······································|·············|·············|·············|···············|··············

// ························································|······································|·············|·············|·············|···············|··············
// |  FlashAggregator                                      ·  flashSwapAllIn                      ·          -  ·          -  ·     535461  ·            1  ·      37.80  │
// ························································|······································|·············|·············|·············|···············|··············
// |  FlashAggregator                                      ·  flashSwapAllOut                     ·          -  ·          -  ·     456173  ·            1  ·      32.20  │
// ························································|······································|·············|·············|·············|···············|··············
// |  FlashAggregator                                      ·  flashSwapExactIn                    ·     551774  ·     564578  ·     557854  ·            3  ·      39.38  │
// ························································|······································|·············|·············|·············|···············|··············
// |  FlashAggregator                                      ·  flashSwapExactOut                   ·     493966  ·     545851  ·     512553  ·            3  ·      36.18  │
// ························································|······································|·············|·············|·············|···············|··············
