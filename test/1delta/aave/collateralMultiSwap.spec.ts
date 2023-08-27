import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { ethers, network, waffle } from 'hardhat'
import {
    MintableERC20,
    WETH9,
    PathTesterBroker__factory,
    PathTesterBroker
} from '../../../types';
import { FeeAmount } from '../../uniswap-v3/periphery/shared/constants';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals';
import { initAaveBroker, AaveBrokerFixture, aaveBrokerFixture, AaveBrokerFixtureInclV2, aaveBrokerFixtureInclV2 } from '../shared/aaveBrokerFixture';
import { expect } from '../shared/expect'
import { initializeMakeSuite, InterestRateMode, AAVEFixture } from '../shared/aaveFixture';
import { addLiquidity, addLiquidityV2, UniswapMinimalFixtureNoTokens, uniswapMinimalFixtureNoTokens } from '../shared/uniswapFixture';
import { formatEther } from 'ethers/lib/utils';
import { encodePath } from '../../uniswap-v3/periphery/shared/path';
import { uniV2Fixture, V2Fixture } from '../shared/uniV2Fixture';
import { encodeAggregatorPathEthers } from '../shared/aggregatorPath';

// we prepare a setup for aave in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('AAVE Brokered Collateral Multi Swap operations', async () => {
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
    let provider: MockProvider
    let uniswapV2: V2Fixture

    before('Deploy Account, Trader, Uniswap and AAVE', async () => {
        [deployer, alice, bob, carol, gabi, test, test0, test1] = await ethers.getSigners();
        aaveTest = await initializeMakeSuite(deployer)
        tokens = Object.values(aaveTest.tokens)
        uniswap = await uniswapMinimalFixtureNoTokens(deployer, aaveTest.tokens["WETH"].address)
        uniswapV2 = await uniV2Fixture(deployer, aaveTest.tokens["WETH"].address)
        broker = await aaveBrokerFixtureInclV2(deployer, uniswap.factory.address, aaveTest.pool.address, uniswapV2.factoryV2.address)

        await initAaveBroker(deployer, broker, uniswap, aaveTest)
        await broker.manager.setUniswapRouter(uniswap.router.address)
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
            await token.connect(gabi).approve(uniswap.router.address, constants.MaxUint256)

            await broker.manager.addAToken(token.address, aaveTest.aTokens[key].address)
            await broker.manager.addSToken(token.address, aaveTest.sTokens[key].address)
            await broker.manager.addVToken(token.address, aaveTest.vTokens[key].address)

        }

        await broker.manager.connect(deployer).approveAAVEPool(tokens.map(t => t.address))

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


    it('allows collateral swap exact in', async () => {

        const supplyTokenIndex = "DAI"
        const supplyTokenIndexOther = "WMATIC"
        const borrowTokenIndex = "AAVE"
        const providedAmount = expandTo18Decimals(50)
        const providedAmountOther = expandTo18Decimals(50)

        const swapAmount = expandTo18Decimals(45)
        const borrowAmount = expandTo18Decimals(90)

        console.log("approve")
        await aaveTest.tokens[supplyTokenIndex].connect(carol).approve(aaveTest.pool.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndexOther].connect(carol).approve(aaveTest.pool.address, constants.MaxUint256)

        // open first position
        await aaveTest.pool.connect(carol).supply(aaveTest.tokens[supplyTokenIndex].address, providedAmount, carol.address, 0)
        await aaveTest.pool.connect(carol).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        // open second position
        await aaveTest.pool.connect(carol).supply(aaveTest.tokens[supplyTokenIndexOther].address, providedAmountOther, carol.address, 0)
        await aaveTest.pool.connect(carol).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndexOther].address, true)

        console.log("borrow")
        await aaveTest.pool.connect(carol).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            carol.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[supplyTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndexOther]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6, 0], // action
            [1, 1], // pid - V3
            3 // flag - borrow variable
        )
        const params = {
            path,
            userAmountProvided: providedAmount,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(98).div(100)
        }


        await aaveTest.aTokens[supplyTokenIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.aTokens[supplyTokenIndexOther].connect(carol).approve(broker.broker.address, constants.MaxUint256)


        // swap collateral
        console.log("collateral swap")
        const t = await aaveTest.aTokens[supplyTokenIndex].balanceOf(carol.address)
        const t2 = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(carol.address)
        console.log(t.toString(), t2.toString())
        // await broker.broker.connect(carol).swapCollateralExactIn(params)

        await broker.trader.connect(carol).swapExactIn(params.amountIn, params.amountOutMinimum, params.path)

        const bb = await aaveTest.pool.getUserAccountData(carol.address)
        const ctIn = await aaveTest.aTokens[supplyTokenIndex].balanceOf(carol.address)
        const ctInOther = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(carol.address)
        expect(ctIn.toString()).to.equal(expandTo18Decimals(5))
        expect(Number(formatEther(ctInOther))).to.greaterThanOrEqual(Number(formatEther(expandTo18Decimals(90))))
    })

    it('allows collateral swap all in', async () => {

        const supplyTokenIndex = "DAI"
        const supplyTokenIndexOther = "WMATIC"
        const borrowTokenIndex = "AAVE"
        const providedAmount = expandTo18Decimals(50)
        const providedAmountOther = expandTo18Decimals(50)

        const swapAmount = expandTo18Decimals(45)
        const borrowAmount = expandTo18Decimals(90)

        console.log("approve")
        await aaveTest.tokens[supplyTokenIndex].connect(test0).approve(aaveTest.pool.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndexOther].connect(test0).approve(aaveTest.pool.address, constants.MaxUint256)

        // open first position
        await aaveTest.pool.connect(test0).supply(aaveTest.tokens[supplyTokenIndex].address, providedAmount, test0.address, 0)
        await aaveTest.pool.connect(test0).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        // open second position
        await aaveTest.pool.connect(test0).supply(aaveTest.tokens[supplyTokenIndexOther].address, providedAmountOther, test0.address, 0)
        await aaveTest.pool.connect(test0).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndexOther].address, true)

        console.log("borrow")
        await aaveTest.pool.connect(test0).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            test0.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[supplyTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndexOther]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6, 0], // action
            [1, 1], // pid - V3
            3 // flag - borrow variable
        )
        const params = {
            path,
            amountOutMinimum: swapAmount.mul(98).div(100)
        }


        await aaveTest.aTokens[supplyTokenIndex].connect(test0).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.aTokens[supplyTokenIndexOther].connect(test0).approve(broker.broker.address, constants.MaxUint256)


        // swap collateral
        console.log("collateral swap")

        const balBefore = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(test0.address)

        await broker.trader.connect(test0).swapAllIn(params.amountOutMinimum, params.path)

        const supplyTokenBalanceAfter = await aaveTest.aTokens[supplyTokenIndex].balanceOf(test0.address)
        const balAfter = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(test0.address)

        expect(supplyTokenBalanceAfter.toString()).to.equal('0')
        expect(Number(formatEther(providedAmount))).to.greaterThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
        expect(Number(formatEther(providedAmount))).to.lessThanOrEqual(Number(formatEther(balAfter.sub(balBefore))) * 1.05)
    })

    it('allows collateral swap exact out', async () => {

        const supplyTokenIndex = "DAI"
        const supplyTokenIndexOther = "WMATIC"
        const borrowTokenIndex = "AAVE"
        const providedAmount = expandTo18Decimals(50)
        const providedAmountOther = expandTo18Decimals(50)

        const swapAmount = expandTo18Decimals(45)
        const borrowAmount = expandTo18Decimals(90)

        console.log("approve")
        await aaveTest.tokens[supplyTokenIndex].connect(gabi).approve(aaveTest.pool.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndexOther].connect(gabi).approve(aaveTest.pool.address, constants.MaxUint256)

        // open first position
        await aaveTest.pool.connect(gabi).supply(aaveTest.tokens[supplyTokenIndex].address, providedAmount, gabi.address, 0)
        await aaveTest.pool.connect(gabi).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        // open second position
        await aaveTest.pool.connect(gabi).supply(aaveTest.tokens[supplyTokenIndexOther].address, providedAmountOther, gabi.address, 0)
        await aaveTest.pool.connect(gabi).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndexOther].address, true)



        console.log("borrow")
        await aaveTest.pool.connect(gabi).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            gabi.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[supplyTokenIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[supplyTokenIndexOther]
        ].map(t => t.address).reverse()
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [3, 1], // action
            [1, 10], // pid
            3 // flag
        )

        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100)
        }

        await aaveTest.aTokens[supplyTokenIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.aTokens[supplyTokenIndexOther].connect(gabi).approve(broker.broker.address, constants.MaxUint256)


        // swap collateral
        console.log("collateral swap", formatEther(params.amountOut))
        const t = await aaveTest.aTokens[supplyTokenIndex].balanceOf(gabi.address)
        const t2 = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(gabi.address)
        console.log(formatEther(t), formatEther(t2))
        await broker.trader.connect(gabi).swapExactOut(params.amountOut, params.amountInMaximum, params.path)

        const ctIn = await aaveTest.aTokens[supplyTokenIndex].balanceOf(gabi.address)
        const ctInOther = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(gabi.address)
        console.log("DAS", formatEther(ctIn), formatEther(ctInOther))
        expect(ctInOther.toString()).to.equal(expandTo18Decimals(95))
        console.log("in", Number(formatEther(ctIn)), "bench", Number(formatEther(expandTo18Decimals(5))))
        expect(Number(formatEther(ctIn))).to.lessThanOrEqual(Number(formatEther(expandTo18Decimals(5))))

    })

})

// ·----------------------------------------------------------------------------------------------|---------------------------|-----------|-----------------------------·
// |                                     Solc version: 0.8.15                                     ·  Optimizer enabled: true  ·  Runs: 1  ·  Block limit: 30000000 gas  │
// ·······························································································|···························|···········|······························
// |  Methods                                                                                                                                                           │
// ························································|······································|·············|·············|···········|···············|··············
// |  Contract                                             ·  Method                              ·  Min        ·  Max        ·  Avg      ·  # calls      ·  usd (avg)  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  swapCollateralExactIn               ·          -  ·          -  ·   553958  ·            1  ·      14.68  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  swapCollateralExactOut              ·          -  ·          -  ·   492461  ·            1  ·      13.05  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  swapCollateralAllIn                 ·          -  ·          -  ·   508276  ·            1  ·      13.47  │
// ························································|······································|·············|·············|···········|···············|··············
