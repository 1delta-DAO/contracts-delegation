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
import { initAaveBroker, aaveBrokerFixture, AaveBrokerFixture } from '../shared/aaveBrokerFixture';
import { expect } from '../shared/expect'
import { initializeMakeSuite, InterestRateMode, AAVEFixture } from '../shared/aaveFixture';
import { uniswapFixtureNoTokens, UniswapFixtureNoTokens } from '../shared/uniswapFixture';
import { formatEther } from 'ethers/lib/utils';
import { encodePath } from '../../uniswap-v3/periphery/shared/path';

// we prepare a setup for aave in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('AAVE Brokered Collateral Swap operations', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let test0: SignerWithAddress;
    let test1: SignerWithAddress;
    let uniswap: UniswapFixtureNoTokens;
    let aaveTest: AAVEFixture;
    let broker: AaveBrokerFixture;
    let tokens: (MintableERC20 | WETH9)[];
    let provider: MockProvider

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

        broker = await aaveBrokerFixture(deployer, uniswap.factory.address, aaveTest.pool.address)

        await initAaveBroker(deployer, broker, uniswap, aaveTest)

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


        await broker.manager.connect(deployer).approveAAVEPool(tokens.map(t => t.address))

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
            aaveTest.tokens[supplyTokenIndexOther]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            userAmountProvided: providedAmount,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(98).div(100)
        }


        await aaveTest.tokens[supplyTokenIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndexOther].connect(carol).approve(broker.broker.address, constants.MaxUint256)


        await aaveTest.aTokens[supplyTokenIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.aTokens[supplyTokenIndexOther].connect(carol).approve(broker.broker.address, constants.MaxUint256)


        // swap collateral
        console.log("collateral swap")
        const t = await aaveTest.aTokens[supplyTokenIndex].balanceOf(carol.address)
        const t2 = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(carol.address)
        console.log(t.toString(), t2.toString())
        await broker.broker.connect(carol).swapCollateralExactIn(params)

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
            aaveTest.tokens[supplyTokenIndexOther]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            amountOutMinimum: providedAmount.mul(98).div(100)
        }


        await aaveTest.tokens[supplyTokenIndex].connect(test0).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndexOther].connect(test0).approve(broker.broker.address, constants.MaxUint256)


        await aaveTest.aTokens[supplyTokenIndex].connect(test0).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.aTokens[supplyTokenIndexOther].connect(test0).approve(broker.broker.address, constants.MaxUint256)


        // swap collateral
        console.log("collateral swap")

        const balBefore = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(test0.address)

        await broker.broker.connect(test0).swapCollateralAllIn(params)

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
            aaveTest.tokens[supplyTokenIndexOther]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))


        const params = {
            path,
            fee: FeeAmount.MEDIUM,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100)
        }


        await aaveTest.tokens[supplyTokenIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.tokens[supplyTokenIndexOther].connect(gabi).approve(broker.broker.address, constants.MaxUint256)


        await aaveTest.aTokens[supplyTokenIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.aTokens[supplyTokenIndexOther].connect(gabi).approve(broker.broker.address, constants.MaxUint256)


        // swap collateral
        console.log("collateral swap")
        const t = await aaveTest.aTokens[supplyTokenIndex].balanceOf(gabi.address)
        const t2 = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(gabi.address)
        console.log(t.toString(), t2.toString())
        await broker.broker.connect(gabi).swapCollateralExactOut(params)

        const ctIn = await aaveTest.aTokens[supplyTokenIndex].balanceOf(gabi.address)
        const ctInOther = await aaveTest.aTokens[supplyTokenIndexOther].balanceOf(gabi.address)
        expect(ctInOther.toString()).to.equal(expandTo18Decimals(95))
        console.log("in", Number(formatEther(ctIn)), "bench", Number(formatEther(expandTo18Decimals(5))))
        expect(Number(formatEther(ctIn))).to.lessThanOrEqual(Number(formatEther(expandTo18Decimals(5))))
    })

})

// ·----------------------------------------------------------------------------------------------|---------------------------|-----------------|-----------------------------·
// |                                     Solc version: 0.8.20                                     ·  Optimizer enabled: true  ·  Runs: 1000000  ·  Block limit: 30000000 gas  │
// ·······························································································|···························|·················|······························
// |  Methods                                                                                                                                                                 │
// ························································|······································|·············|·············|·················|···············|··············
// |  Contract                                             ·  Method                              ·  Min        ·  Max        ·  Avg            ·  # calls      ·  usd (avg)  │
// ······················································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  swapCollateralExactIn               ·          -  ·          -  ·   470337  ·            1  ·      12.46  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderModule                               ·  swapCollateralExactOut              ·          -  ·          -  ·   425437  ·            1  ·      11.27  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  swapCollateralAllIn                 ·          -  ·          -  ·   435024  ·            1  ·      11.53  │
// ························································|······································|·············|·············|···········|···············|··············


