import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { ethers, network, waffle } from 'hardhat'
import {
    MintableERC20,
    WETH9,
    IERC20__factory
} from '../../../types';
import { FeeAmount, TICK_SPACINGS } from '../../uniswap-v3/periphery/shared/constants';
import { encodePriceSqrt } from '../../uniswap-v3/periphery/shared/encodePriceSqrt';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals';
import { getMaxTick, getMinTick } from '../../uniswap-v3/periphery/shared/ticks';
import { AaveBrokerFixtureInclV2, aaveBrokerFixtureInclV2, initAaveBroker } from '../shared/aaveBrokerFixture';
import { expect } from '../shared/expect'
import { initializeMakeSuite, InterestRateMode, AAVEFixture } from '../shared/aaveFixture';
import { addLiquidityV2, uniswapFixtureNoTokens, UniswapFixtureNoTokens } from '../shared/uniswapFixture';
import { formatEther } from 'ethers/lib/utils';
import { MockProvider } from 'ethereum-waffle';
import { encodePath } from '../../uniswap-v3/periphery/shared/path';
import { uniV2Fixture, V2Fixture } from '../shared/uniV2Fixture';
import { encodeAggregatorPathEthers } from '../shared/aggregatorPath';

// we prepare a setup for aave in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('AAVE Brokered Loan Swap operations', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let test0: SignerWithAddress;
    let test1: SignerWithAddress;
    let uniswap: UniswapFixtureNoTokens;
    let aaveTest: AAVEFixture;
    let broker: AaveBrokerFixtureInclV2;
    let tokens: (MintableERC20 | WETH9)[];
    let uniswapV2: V2Fixture


    async function addLiquidity(signer: SignerWithAddress, tokenAddressA: string, tokenAddressB: string, amountA: BigNumber, amountB: BigNumber) {
        if (tokenAddressA.toLowerCase() > tokenAddressB.toLowerCase())
            [tokenAddressA, tokenAddressB, amountA, amountB] = [tokenAddressB, tokenAddressA, amountB, amountA]

        await uniswap.nft.connect(signer).createAndInitializePoolIfNecessary(
            tokenAddressA,
            tokenAddressB,
            FeeAmount.MEDIUM,
            encodePriceSqrt(1, 1)
        )

        const liquidityParams = {
            token0: tokenAddressA,
            token1: tokenAddressB,
            fee: FeeAmount.MEDIUM,
            tickLower: getMinTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
            tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
            recipient: deployer.address,
            amount0Desired: amountA,
            amount1Desired: amountB,
            amount0Min: 0,
            amount1Min: 0,
            deadline: 1,
        }

        const tA = await new ethers.Contract(tokenAddressA, IERC20__factory.createInterface(), signer)
        await tA.connect(signer).approve(uniswap.nft.address, constants.MaxUint256)

        const tB = await new ethers.Contract(tokenAddressB, IERC20__factory.createInterface(), signer)
        await tB.connect(signer).approve(uniswap.nft.address, constants.MaxUint256)

        console.log("add liquidity", tokenAddressA, tokenAddressB)

        return uniswap.nft.connect(signer).mint(liquidityParams)
    }


    before('Deploy Account, Trader, Uniswap and AAVE', async () => {
        [deployer, alice, bob, carol, gabi, test0, test1] = await ethers.getSigners();


        aaveTest = await initializeMakeSuite(deployer)
        tokens = Object.values(aaveTest.tokens)
        uniswap = await uniswapFixtureNoTokens(deployer, aaveTest.tokens["WETH"].address)
        uniswapV2 = await uniV2Fixture(deployer, aaveTest.tokens["WETH"].address)
        broker = await aaveBrokerFixtureInclV2(deployer, uniswap.factory.address, aaveTest.pool.address, uniswapV2.factoryV2.address, aaveTest.tokens["WETH"].address)

        await initAaveBroker(deployer, broker as any, aaveTest.pool.address)

        // approve & fund wallets
        let keys = Object.keys(aaveTest.tokens)
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i]
            await aaveTest.tokens[key].connect(deployer).approve(aaveTest.pool.address, constants.MaxUint256)
            if (key === "WETH") {
                await (aaveTest.tokens[key] as WETH9).deposit({ value: expandTo18Decimals(5_000) })
                await aaveTest.pool.connect(deployer).supply(aaveTest.tokens[key].address, expandTo18Decimals(2_000), deployer.address, 0)

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
            await broker.manager.addAToken(token.address, aaveTest.aTokens[key].address)
            await broker.manager.addSToken(token.address, aaveTest.sTokens[key].address)
            await broker.manager.addVToken(token.address, aaveTest.vTokens[key].address)
        }


        await broker.manager.connect(deployer).approveLendingPool(tokens.map(t => t.address))

        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["USDC"].address,
            expandTo18Decimals(100_000),
            BigNumber.from(100_000e6) // usdc has 6 decimals
        )

        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["AAVE"].address,
            expandTo18Decimals(100_000),
            expandTo18Decimals(100_000)
        )

        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(100_000),
            expandTo18Decimals(100_000)
        )

        await addLiquidity(
            deployer,
            aaveTest.tokens["AAVE"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(100_000),
            expandTo18Decimals(100_000)
        )

        await addLiquidityV2(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["USDC"].address,
            expandTo18Decimals(100_000),
            BigNumber.from(100_000e6), // usdc has 6 decimals
            uniswapV2
        )

        await addLiquidityV2(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["AAVE"].address,
            expandTo18Decimals(100_000),
            expandTo18Decimals(100_000),
            uniswapV2
        )

        await addLiquidityV2(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(100_000),
            expandTo18Decimals(100_000),
            uniswapV2
        )

        await addLiquidityV2(
            deployer,
            aaveTest.tokens["AAVE"].address,
            aaveTest.tokens["WMATIC"].address,
            expandTo18Decimals(100_000),
            expandTo18Decimals(100_000),
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
        ).to.be.revertedWith('35') // 35 is the error related to healt factor
    })


    it('allows loan swap exact in same decimals', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "AAVE"
        const borrowTokenIndexOther = "WMATIC"
        const providedAmount = expandTo18Decimals(180)


        const swapAmount = expandTo18Decimals(70)
        const borrowAmount = expandTo18Decimals(75)
        const borrowAmountOther = expandTo18Decimals(75)


        // transfer to wallet
        await aaveTest.tokens[supplyTokenIndex].connect(deployer).transfer(carol.address, providedAmount)

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
            aaveTest.tokens[borrowTokenIndexOther]
        ].map(t => t.address)
        // const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [8], // action
            [9], // pid
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
        // await broker.broker.connect(carol).swapBorrowExactIn(params)
        await broker.trader.connect(carol).flashSwapExactIn(params.amountIn, params.amountOutMinimum, params.path)

        const ctIn = await aaveTest.vTokens[borrowTokenIndex].balanceOf(carol.address)
        const ctInOther = await aaveTest.vTokens[borrowTokenIndexOther].balanceOf(carol.address)
        expect(Number(formatEther(ctIn))).to.greaterThanOrEqual(Number(formatEther(expandTo18Decimals(145))))
        expect(Number(formatEther(ctIn))).to.lessThanOrEqual(Number(formatEther(expandTo18Decimals(145))) * 1.000001)
        expect(Number(formatEther(ctInOther))).to.greaterThanOrEqual(Number(formatEther(expandTo18Decimals(5))))
    })

    it('allows loan swap exact out', async () => {
        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "AAVE"
        const borrowTokenIndexOther = "WMATIC"
        const providedAmount = expandTo18Decimals(180)


        const swapAmount = expandTo18Decimals(70)
        const borrowAmount = expandTo18Decimals(75)
        const borrowAmountOther = expandTo18Decimals(75)


        // transfer to wallet
        await aaveTest.tokens[supplyTokenIndex].connect(deployer).transfer(gabi.address, providedAmount)

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
            aaveTest.tokens[borrowTokenIndexOther]
        ].map(t => t.address).reverse()
        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [5], // action
            [9], // pid
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


    it('allows loan swap all out', async () => {
        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "AAVE"
        const borrowTokenIndexOther = "WMATIC"

        const providedAmount = expandTo18Decimals(200)
        const borrowAmount = expandTo18Decimals(80)
        const borrowAmountOther = expandTo18Decimals(75)


        // transfer to wallet
        await aaveTest.tokens[supplyTokenIndex].connect(deployer).transfer(test0.address, providedAmount)

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
            aaveTest.tokens[borrowTokenIndexOther]
        ].map(t => t.address).reverse()
        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [5], // action
            [9], // pid
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

        // swap loan
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
// |  AAVEMarginTraderModule              ·  swapBorrowExactIn                   ·          -  ·          -  ·   470890  ·            1  ·      11.58  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule              ·  swapBorrowExactOut                  ·          -  ·          -  ·   445867  ·            1  ·      10.97  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                   ·  swapBorrowAllOut                    ·          -  ·          -  ·   446535  ·            1  ·      10.98  │
// ·······································|······································|·············|·············|···········|···············|··············

// V3
// ·······································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                       ·  swapExactIn                         ·          -  ·          -  ·     486130  ·            1  ·      96.26  │
// ·······································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                       ·  swapExactOut                        ·          -  ·          -  ·     441112  ·            1  ·      87.34  │
// ·······································|······································|·············|·············|·············|···············|··············


// V2
// ·······································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                       ·  swapAllOut                          ·          -  ·          -  ·     435647  ·            1  ·      29.59  │
// ·······································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                       ·  swapExactIn                         ·          -  ·          -  ·     489685  ·            1  ·      33.27  │
// ·······································|······································|·············|·············|·············|···············|··············
// |  MarginTrading                       ·  swapExactOut                        ·          -  ·          -  ·     435310  ·            1  ·      29.57  │
// ·······································|······································|·············|·············|·············|···············|··············
