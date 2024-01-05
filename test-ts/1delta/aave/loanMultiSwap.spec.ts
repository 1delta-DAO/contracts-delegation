import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { ethers, network } from 'hardhat'
import {
    MintableERC20,
    WETH9,
    PathTesterBroker,
    PathTesterBroker__factory
} from '../../../types';
import { FeeAmount } from '../../uniswap-v3/periphery/shared/constants';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals';
import { AaveBrokerFixtureInclV2, aaveBrokerFixtureInclV2, initAaveBroker } from '../shared/aaveBrokerFixture';
import { expect } from '../shared/expect'
import { initializeMakeSuite, InterestRateMode, AAVEFixture } from '../shared/aaveFixture';
import { addLiquidity, addLiquidityV2, uniswapMinimalFixtureNoTokens, UniswapMinimalFixtureNoTokens } from '../shared/uniswapFixture';
import { formatEther } from 'ethers/lib/utils';
import { MockProvider } from 'ethereum-waffle';
import { uniV2Fixture, V2Fixture } from '../shared/uniV2Fixture';
import { encodeAggregatorPathEthers } from '../shared/aggregatorPath';

// we prepare a setup for aave in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('AAVE Brokered Loan Multi Swap operations', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let test: SignerWithAddress;
    let test0: SignerWithAddress;
    let test1: SignerWithAddress;
    let uniswap: UniswapMinimalFixtureNoTokens;
    let aaveTest: AAVEFixture;
    let broker: AaveBrokerFixtureInclV2;
    let tokens: (MintableERC20 | WETH9)[];
    let pathTester: PathTesterBroker
    let uniswapV2: V2Fixture

    before('Deploy Account, Trader, Uniswap and AAVE', async () => {
        [deployer, alice, bob, carol, gabi, test, test0, test1] = await ethers.getSigners();

        aaveTest = await initializeMakeSuite(deployer)
        tokens = Object.values(aaveTest.tokens)
        uniswap = await uniswapMinimalFixtureNoTokens(deployer, aaveTest.tokens["WETH"].address)
        uniswapV2 = await uniV2Fixture(deployer, aaveTest.tokens["WETH"].address)
        broker = await aaveBrokerFixtureInclV2(deployer, uniswap.factory.address, aaveTest.pool.address, uniswapV2.factoryV2.address, aaveTest.tokens["WETH"].address)

        pathTester = await new PathTesterBroker__factory(deployer).deploy()
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
                await aaveTest.tokens[key].connect(deployer).transfer(test1.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test0.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(gabi.address, expandTo18Decimals(1_000_000))

                await aaveTest.tokens[key].connect(bob).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(alice).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(carol).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test1).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test0).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(gabi).approve(aaveTest.pool.address, ethers.constants.MaxUint256)

            }

            const token = aaveTest.tokens[key]
            await broker.manager.addAToken(token.address, aaveTest.aTokens[key].address)
            await broker.manager.addSToken(token.address, aaveTest.sTokens[key].address)
            await broker.manager.addVToken(token.address, aaveTest.vTokens[key].address)

        }

        await broker.manager.connect(deployer).approveLendingPool(tokens.map(t => t.address))

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
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswapV2
        )

        console.log("add liquidity V2 AAVE WETH")
        await addLiquidityV2(
            deployer,
            aaveTest.tokens["AAVE"].address,
            aaveTest.tokens["WETH"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(200),
            uniswapV2
        )

        console.log("add liquidity V2 AAVE WMATIC")
        await addLiquidityV2(
            deployer,
            aaveTest.tokens["AAVE"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswapV2
        )

        console.log("add liquidity V2 WETH MATIC")
        await addLiquidityV2(
            deployer,
            aaveTest.tokens["WETH"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(200),
            expandTo18Decimals(1_000_000),
            uniswapV2
        )

    })

    // we illustrate that the trade, if attempted manually in two trades, is not possible
    it('refuses manual creation', async () => {

        const supplyTokenIndex = "DAI"
        const supplyTokenIndexOther = "WETH"
        const borrowTokenIndex = "AAVE"
        const providedAmount = expandTo18Decimals(50)
        const providedAmountOther = expandTo18Decimals(50)

        const borrowAmount = expandTo18Decimals(90)

        // transfer to wallet
        await aaveTest.tokens[supplyTokenIndex].connect(deployer).transfer(bob.address, expandTo18Decimals(50))
        await aaveTest.tokens[supplyTokenIndexOther].connect(deployer).transfer(bob.address, expandTo18Decimals(50))

        console.log("approve")
        await aaveTest.tokens[supplyTokenIndex].connect(bob).approve(aaveTest.pool.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndexOther].connect(bob).approve(aaveTest.pool.address, constants.MaxUint256)

        // open first position
        await aaveTest.pool.connect(bob).supply(aaveTest.tokens[supplyTokenIndex].address, providedAmount, bob.address, 0)
        await aaveTest.pool.connect(bob).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        // open second position
        await aaveTest.pool.connect(bob).supply(aaveTest.tokens[supplyTokenIndexOther].address, providedAmountOther, bob.address, 0)
        await aaveTest.pool.connect(bob).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndexOther].address, true)

        console.log("borrow")
        await aaveTest.pool.connect(bob).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            bob.address
        )
        console.log("attempt withdraw")
        await expect(
            aaveTest.pool.connect(bob).withdraw(
                aaveTest.tokens[supplyTokenIndex].address,
                providedAmount,
                bob.address
            )
        ).to.be.revertedWith('35') // 35 is the error related to health factor
    })


    it('allows loan swap multi exact in', async () => {

        const supplyTokenIndex = "AAVE"
        const borrowTokenIndex = "DAI"
        const borrowTokenIndexOther = "WMATIC"
        const providedAmount = expandTo18Decimals(180)

        const swapAmount = expandTo18Decimals(70)
        const borrowAmount = expandTo18Decimals(75)
        const borrowAmountOther = expandTo18Decimals(75)

        console.log("approve")
        await aaveTest.tokens[supplyTokenIndex].connect(carol).approve(aaveTest.pool.address, constants.MaxUint256)

        // open position
        await aaveTest.pool.connect(carol).supply(aaveTest.tokens[supplyTokenIndex].address, providedAmount, carol.address, 0)
        await aaveTest.pool.connect(carol).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)


        console.log("borrow")
        await aaveTest.pool.connect(carol).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            carol.address
        )


        await aaveTest.pool.connect(carol).borrow(
            aaveTest.tokens[borrowTokenIndexOther].address,
            borrowAmountOther,
            InterestRateMode.VARIABLE,
            0,
            carol.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[borrowTokenIndexOther]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [8, 0], // action
            [1, 1], // pid
            2 // flag
        )
        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            interestRateMode: 22,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(98).div(100)
        }

        await aaveTest.vTokens[borrowTokenIndex].connect(carol).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndexOther].connect(carol).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.sTokens[borrowTokenIndex].connect(carol).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.sTokens[borrowTokenIndexOther].connect(carol).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        // swap loan
        console.log("loan swap")
        const t = await aaveTest.aTokens[supplyTokenIndex].balanceOf(carol.address)
        const t2 = await aaveTest.aTokens[borrowTokenIndexOther].balanceOf(carol.address)
        console.log(t.toString(), t2.toString())
        await broker.trader.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)
        const ctIn = await aaveTest.vTokens[borrowTokenIndex].balanceOf(carol.address)
        const ctInOther = await aaveTest.vTokens[borrowTokenIndexOther].balanceOf(carol.address)
        expect(Number(formatEther(ctIn))).to.greaterThanOrEqual(Number(formatEther(expandTo18Decimals(145))))
        expect(Number(formatEther(ctIn))).to.lessThanOrEqual(Number(formatEther(expandTo18Decimals(145))) * 1.000001)
        expect(Number(formatEther(ctInOther))).to.greaterThanOrEqual(Number(formatEther(expandTo18Decimals(5))))
    })

    it('allows loan swap multi exact out', async () => {
        const supplyTokenIndex = "AAVE"
        const borrowTokenIndex = "DAI"
        const borrowTokenIndexOther = "WMATIC"
        const providedAmount = expandTo18Decimals(180)


        const swapAmount = expandTo18Decimals(70)
        const borrowAmount = expandTo18Decimals(75)
        const borrowAmountOther = expandTo18Decimals(75)

        console.log("approve")
        await aaveTest.tokens[supplyTokenIndex].connect(gabi).approve(aaveTest.pool.address, constants.MaxUint256)

        // open position
        await aaveTest.pool.connect(gabi).supply(aaveTest.tokens[supplyTokenIndex].address, providedAmount, gabi.address, 0)
        await aaveTest.pool.connect(gabi).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)


        console.log("borrow")
        await aaveTest.pool.connect(gabi).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            gabi.address
        )


        await aaveTest.pool.connect(gabi).borrow(
            aaveTest.tokens[borrowTokenIndexOther].address,
            borrowAmountOther,
            InterestRateMode.VARIABLE,
            0,
            gabi.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[borrowTokenIndexOther]
        ].map(t => t.address).reverse()
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [5, 1], // action
            [1, 10], // pid
            2 // flag
        )
        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            interestRateMode: 22,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100)
        }

        await aaveTest.vTokens[borrowTokenIndex].connect(gabi).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndexOther].connect(gabi).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.sTokens[borrowTokenIndex].connect(gabi).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.sTokens[borrowTokenIndexOther].connect(gabi).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        // swap loan
        console.log("loan swap")
        const t = await aaveTest.aTokens[supplyTokenIndex].balanceOf(gabi.address)
        const t2 = await aaveTest.aTokens[borrowTokenIndexOther].balanceOf(gabi.address)
        console.log(t.toString(), t2.toString())
        await broker.trader.connect(gabi).flashSwapExactOut(params.amountOut, params.amountInMaximum, params.path)

        const ctIn = await aaveTest.vTokens[borrowTokenIndex].balanceOf(gabi.address)
        const ctInOther = await aaveTest.vTokens[borrowTokenIndexOther].balanceOf(gabi.address)
        expect(Number(formatEther(ctIn))).to.greaterThanOrEqual(Number(formatEther(expandTo18Decimals(145))))
        expect(Number(formatEther(ctIn))).to.lessThanOrEqual(Number(formatEther(expandTo18Decimals(145))) * 1.01) // uniswap slippage
        expect(Number(formatEther(ctInOther))).to.greaterThanOrEqual(Number(formatEther(expandTo18Decimals(5))))
    })


    it('allows loan swap multi all out', async () => {
        const supplyTokenIndex = "AAVE"
        const borrowTokenIndex = "DAI"
        const borrowTokenIndexOther = "WMATIC"

        const providedAmount = expandTo18Decimals(200)
        const borrowAmount = expandTo18Decimals(80)
        const borrowAmountOther = expandTo18Decimals(75)

        console.log("approve")
        await aaveTest.tokens[supplyTokenIndex].connect(test0).approve(aaveTest.pool.address, constants.MaxUint256)

        // open position
        await aaveTest.pool.connect(test0).supply(aaveTest.tokens[supplyTokenIndex].address, providedAmount, test0.address, 0)
        await aaveTest.pool.connect(test0).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        console.log("borrow")
        await aaveTest.pool.connect(test0).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            test0.address
        )

        await aaveTest.pool.connect(test0).borrow(
            aaveTest.tokens[borrowTokenIndexOther].address,
            borrowAmountOther,
            InterestRateMode.VARIABLE,
            0,
            test0.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[borrowTokenIndexOther]
        ].map(t => t.address).reverse()
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [5, 1], // action
            [1, 10], // pid
            2 // flag
        )
        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            interestRateMode: 22,
            amountInMaximum: borrowAmountOther.mul(102).div(100)
        }

        await aaveTest.vTokens[borrowTokenIndex].connect(test0).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndexOther].connect(test0).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)

        await aaveTest.sTokens[borrowTokenIndex].connect(test0).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)
        await aaveTest.sTokens[borrowTokenIndexOther].connect(test0).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)


        // increase ime to make sure that interest accrues
        await network.provider.send("evm_increaseTime", [3600])
        await network.provider.send("evm_mine")

        const borrowFromBefore = await aaveTest.vTokens[borrowTokenIndex].balanceOf(test0.address)

        await broker.trader.connect(test0).flashSwapAllOut(params.amountInMaximum, params.path)

        const borrowFromAfter = await aaveTest.vTokens[borrowTokenIndex].balanceOf(test0.address)
        const borrowToAfter = await aaveTest.vTokens[borrowTokenIndexOther].balanceOf(test0.address)

        expect(borrowToAfter.toString()).to.eq('0')

        expect(Number(formatEther(borrowFromBefore.add(borrowAmountOther)))).to.greaterThanOrEqual(Number(formatEther(borrowFromAfter)) * 0.95)
        expect(Number(formatEther(borrowFromBefore.add(borrowAmountOther)))).to.lessThanOrEqual(Number(formatEther(borrowFromAfter))) // uniswap slippage
    })

})

// ·----------------------------------------------------------------------------------------------|---------------------------|-----------|-----------------------------·
// |                                     Solc version: 0.8.15                                     ·  Optimizer enabled: true  ·  Runs: 1  ·  Block limit: 30000000 gas  │
// ·······························································································|···························|···········|······························
// |  Methods                                                                                                                                                           │
// ························································|······································|·············|·············|···········|···············|··············
// |  Contract                                             ·  Method                              ·  Min        ·  Max        ·  Avg      ·  # calls      ·  usd (avg)  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  swapBorrowExactIn                   ·          -  ·          -  ·   561244  ·            1  ·      13.81  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  swapBorrowExactOut                  ·          -  ·          -  ·   513035  ·            1  ·      12.62  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                   ·  swapBorrowAllOut                    ·          -  ·          -  ·   513670  ·            1  ·      12.64  │
// ·······································|······································|·············|·············|···········|···············|··············
