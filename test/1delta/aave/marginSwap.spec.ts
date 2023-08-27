import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
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
import { initAaveBroker, aaveBrokerFixture, AaveBrokerFixture, ONE_18, AaveBrokerFixtureInclV2, aaveBrokerFixtureInclV2 } from '../shared/aaveBrokerFixture';
import { expect } from '../shared/expect'
import { initializeMakeSuite, InterestRateMode, AAVEFixture, deposit } from '../shared/aaveFixture';
import { addLiquidity, addLiquidityV2, uniswapMinimalFixtureNoTokens, UniswapMinimalFixtureNoTokens } from '../shared/uniswapFixture';
import { formatEther } from 'ethers/lib/utils';
import { encodePath } from '../../uniswap-v3/periphery/shared/path';
import { uniV2Fixture, V2Fixture } from '../shared/uniV2Fixture';
import { encodeAggregatorPathEthers } from '../shared/aggregatorPath';

// we prepare a setup for aave in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('AAVE Brokered Margin Swap operations', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let test: SignerWithAddress;
    let test1: SignerWithAddress;
    let test2: SignerWithAddress;
    let uniswap: UniswapMinimalFixtureNoTokens;
    let aaveTest: AAVEFixture;
    let broker: AaveBrokerFixtureInclV2;
    let tokens: (MintableERC20 | WETH9)[];
    let uniswapV2: V2Fixture

    before('Deploy Account, Trader, Uniswap and AAVE', async () => {
        [deployer, alice, bob, carol, gabi, test, test1, test2] = await ethers.getSigners();



        aaveTest = await initializeMakeSuite(deployer)
        tokens = Object.values(aaveTest.tokens)
        uniswap = await uniswapMinimalFixtureNoTokens(deployer, aaveTest.tokens["WETH"].address)
        uniswapV2 = await uniV2Fixture(deployer, aaveTest.tokens["WETH"].address)
        broker = await aaveBrokerFixtureInclV2(deployer, uniswap.factory.address, aaveTest.pool.address, uniswapV2.factoryV2.address)

        await initAaveBroker(deployer, broker, uniswap, aaveTest)

        // approve & fund wallets
        let keys = Object.keys(aaveTest.tokens)
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i]
            await aaveTest.tokens[key].connect(deployer).approve(aaveTest.pool.address, constants.MaxUint256)
            if (key === "WETH") {
                await (aaveTest.tokens[key] as WETH9).deposit({ value: expandTo18Decimals(1_000) })
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
                await aaveTest.tokens[key].connect(deployer).transfer(gabi.address, expandTo18Decimals(1_000_000))

                await aaveTest.tokens[key].connect(bob).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(alice).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(carol).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test1).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test2).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
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

        await broker.manager.connect(deployer).approveAAVEPool(tokens.map(t => t.address))

        console.log("add liquidity")
        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["USDC"].address,
            expandTo18Decimals(100_000),
            BigNumber.from(100_000e6), // usdc has 6 decimals
            uniswap
        )

        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["AAVE"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        await addLiquidityV2(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["USDC"].address,
            expandTo18Decimals(100_000),
            expandTo18Decimals(100_000),
            uniswapV2
        )

        await addLiquidityV2(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["AAVE"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
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

    // we illustrate that the trade, if attempted manually in two trades, is not possible
    it('refuses manual creation', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "AAVE"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        await aaveTest.tokens[supplyTokenIndex].connect(bob).approve(aaveTest.pool.address, constants.MaxUint256)
        await aaveTest.pool.connect(bob).supply(aaveTest.tokens[supplyTokenIndex].address, ONE_18, bob.address, 0)
        await aaveTest.pool.connect(bob).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        // open margin position manually
        await aaveTest.pool.connect(bob).supply(aaveTest.tokens[supplyTokenIndex].address, providedAmount, bob.address, 0)
        await aaveTest.pool.connect(bob).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)
        await expect(
            aaveTest.pool.connect(bob).borrow(
                aaveTest.tokens[borrowTokenIndex].address,
                swapAmount,
                InterestRateMode.VARIABLE,
                0,
                bob.address
            )
        ).to.be.revertedWith('36')
    })

    it('allows margin swap exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "AAVE"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)


        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [6], // action
            [1], // pid - V3
            2 // flag - borrow variable
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(99).div(100)
        }

        await deposit(aaveTest, supplyTokenIndex, carol, providedAmount)

        await aaveTest.tokens[borrowTokenIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(carol).approveDelegation(broker.broker.address, constants.MaxUint256)

        await aaveTest.sTokens[borrowTokenIndex].connect(carol).approveDelegation(broker.broker.address, constants.MaxUint256)

        await aaveTest.tokens[supplyTokenIndex].connect(carol).approve(aaveTest.pool.address, constants.MaxUint256)
        await aaveTest.pool.connect(carol).supply(aaveTest.tokens[supplyTokenIndex].address, ONE_18, carol.address, 0)
        await aaveTest.pool.connect(carol).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        // open margin position
        await broker.trader.connect(carol).swapExactIn(params.amountIn, params.amountOutMinimum, params.path)
        const bb = await aaveTest.pool.getUserAccountData(carol.address)
        expect(bb.totalDebtBase.toString()).to.equal(swapAmount)
    })

    it('allows margin swap exact out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "AAVE"
        const providedAmount = expandTo18Decimals(500)

        const swapAmount = expandTo18Decimals(950)

        await aaveTest.tokens[borrowTokenIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(gabi).approveDelegation(broker.broker.address, constants.MaxUint256)

        await aaveTest.sTokens[borrowTokenIndex].connect(gabi).approveDelegation(broker.broker.address, constants.MaxUint256)

        await aaveTest.tokens[supplyTokenIndex].connect(gabi).approve(aaveTest.pool.address, constants.MaxUint256)

        // enable collateral
        await aaveTest.pool.connect(gabi).supply(aaveTest.tokens[supplyTokenIndex].address, ONE_18, gabi.address, 0)
        await aaveTest.pool.connect(gabi).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)

        const balAfter = await aaveTest.tokens[borrowTokenIndex].balanceOf(test.address)
        const balOther = await aaveTest.tokens[supplyTokenIndex].balanceOf(test.address)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // reverse path for exact out
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [3], // action
            [1], // pid
            2 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(105).div(100)
        }

        await deposit(aaveTest, supplyTokenIndex, gabi, providedAmount)

        // open margin position
        await broker.trader.connect(gabi).swapExactOut(params.amountOut, params.amountInMaximum, params.path)
        const bb = await aaveTest.pool.getUserAccountData(gabi.address)
        expect(bb.totalCollateralBase.toString()).to.equal(swapAmount.add(providedAmount).add(ONE_18).toString())

    })

    it('allows trimming margin position exact in', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "AAVE"

        const swapAmount = expandTo18Decimals(900)


        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // for trimming, we have to revert the swap path
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [8], // action
            [1], // pid
            3 // flag
        )
        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            interestRateMode: InterestRateMode.VARIABLE,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(99).div(100)
        }
        await aaveTest.aTokens[supplyTokenIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndex].connect(carol).approveDelegation(broker.broker.address, constants.MaxUint256)

        const bBefore = await aaveTest.pool.getUserAccountData(carol.address)

        // open margin position
        await broker.trader.connect(carol).swapExactIn(params.amountIn, params.amountOutMinimum, params.path)
        const bAfter = await aaveTest.pool.getUserAccountData(carol.address)
        expect(Number(formatEther(bAfter.totalDebtBase))).to.be.
            lessThanOrEqual(Number(formatEther(bBefore.totalDebtBase.sub(swapAmount))) * 1.05)

        expect(Number(formatEther(bAfter.totalDebtBase))).to.be.
            greaterThanOrEqual(Number(formatEther(bBefore.totalDebtBase.sub(swapAmount))))


        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            greaterThanOrEqual(Number(formatEther(bBefore.totalCollateralBase.sub(swapAmount))))

        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            lessThanOrEqual(Number(formatEther(bBefore.totalCollateralBase.sub(swapAmount))) * 1.001)
    })

    it('allows trimming margin position all in', async () => {

        const supplyTokenIndex = "DAI"
        const supplyTokenOtherIndex = "WMATIC"
        const borrowTokenIndex = "AAVE"

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
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address).reverse()

        // for trimming, we have to revert the swap path
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [8], // action
            [1], // pid
            3 // flag
        )

        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOutMinimum: supply.mul(95).div(100)
        }

        await aaveTest.aTokens[supplyTokenIndex].connect(test1).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndex].connect(test1).approveDelegation(broker.broker.address, constants.MaxUint256)

        // increase ime to make sure that interest accrues
        await network.provider.send("evm_increaseTime", [3600])
        await network.provider.send("evm_mine")

        const bBefore = await aaveTest.pool.getUserAccountData(test1.address)

        // open margin position
        await broker.trader.connect(test1).swapAllIn(params.amountOutMinimum, params.path)

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
        const borrowTokenIndex = "AAVE"

        const swapAmount = expandTo18Decimals(900)

        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [5], // action
            [1], // pid
            3 // flag
        )
        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            amountInMaximum: swapAmount.mul(102).div(100),
            amountOut: swapAmount,
            interestRateMode: InterestRateMode.VARIABLE,
        }

        await aaveTest.aTokens[supplyTokenIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndex].connect(gabi).approveDelegation(broker.broker.address, constants.MaxUint256)

        const bBefore = await aaveTest.pool.getUserAccountData(gabi.address)

        // trim margin position
        await broker.trader.connect(gabi).swapExactOut(params.amountOut, params.amountInMaximum, params.path)

        const bAfter = await aaveTest.pool.getUserAccountData(gabi.address)
        expect(Number(formatEther(bAfter.totalDebtBase))).to.be.
            lessThanOrEqual(Number(formatEther(bBefore.totalDebtBase.sub(swapAmount))) * 1.005)

        expect(Number(formatEther(bAfter.totalDebtBase))).to.be.
            greaterThanOrEqual(Number(formatEther(bBefore.totalDebtBase.sub(swapAmount))))


        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            lessThan(Number(formatEther(bBefore.totalCollateralBase.sub(swapAmount))) * 1.005)

        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            greaterThan(Number(formatEther(bBefore.totalCollateralBase.sub(swapAmount))) * 0.995)
    })

    it('allows trimming margin position all out', async () => {

        const supplyTokenIndex = "DAI"
        const borrowTokenIndex = "AAVE"

        const supply = expandTo18Decimals(900)
        const borrow = expandTo18Decimals(600)

        // set up scenario
        await aaveTest.pool.connect(test2).supply(aaveTest.tokens[supplyTokenIndex].address, supply, test2.address, 0)
        await aaveTest.pool.connect(test2).setUserUseReserveAsCollateral(aaveTest.tokens[supplyTokenIndex].address, true)
        await aaveTest.pool.connect(test2).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrow,
            InterestRateMode.VARIABLE,
            0,
            test2.address
        )


        let _tokensInRoute = [
            aaveTest.tokens[borrowTokenIndex],
            aaveTest.tokens[supplyTokenIndex]
        ].map(t => t.address)
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [5], // action
            [1], // pid
            3 // flag
        )
        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            amountInMaximum: borrow.mul(105).div(100),
            interestRateMode: InterestRateMode.VARIABLE,
        }

        await aaveTest.aTokens[supplyTokenIndex].connect(test2).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.vTokens[borrowTokenIndex].connect(test2).approveDelegation(broker.broker.address, constants.MaxUint256)

        // increase ime to make sure that interest accrues
        await network.provider.send("evm_increaseTime", [3600])
        await network.provider.send("evm_mine")

        const bBefore = await aaveTest.pool.getUserAccountData(test2.address)

        // trim margin position
        await broker.trader.connect(test2).swapAllOut(params.amountInMaximum, params.path)


        const bAfter = await aaveTest.pool.getUserAccountData(test2.address)

        expect(Number(formatEther(bAfter.totalDebtBase))).to.eq(0)


        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            lessThan(Number(formatEther(bBefore.totalCollateralBase.sub(borrow))) * 1.005)

        expect(Number(formatEther(bAfter.totalCollateralBase))).to.be.
            greaterThan(Number(formatEther(bBefore.totalCollateralBase.sub(borrow))) * 0.95)
    })

})

// ·----------------------------------------------------------------------------------------------|---------------------------|-----------|-----------------------------·
// |                                     Solc version: 0.8.15                                     ·  Optimizer enabled: true  ·  Runs: 1  ·  Block limit: 30000000 gas  │
// ·······························································································|···························|···········|······························
// |  Methods                                                                                                                                                           │
// ························································|······································|·············|·············|···········|···············|··············
// |  Contract                                             ·  Method                              ·  Min        ·  Max        ·  Avg      ·  # calls      ·  usd (avg)  │
// ························································|······································|·············|·············|···········|···············|··············
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  openMarginPositionExactIn           ·          -  ·          -  ·   451315  ·            1  ·      11.95  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  openMarginPositionExactOut          ·          -  ·          -  ·   411827  ·            1  ·      10.90  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  trimMarginPositionExactIn           ·          -  ·          -  ·   452666  ·            1  ·      11.99  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  trimMarginPositionExactOut          ·          -  ·          -  ·   416564  ·            1  ·      11.03  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  trimMarginPositionAllIn             ·          -  ·          -  ·   447252  ·            1  ·      11.84  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  trimMarginPositionAllOut            ·          -  ·          -  ·   399518  ·            1  ·      10.58  │
// ························································|······································|·············|·············|···········|···············|··············

