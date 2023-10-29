import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { formatEther } from 'ethers/lib/utils';
import { ethers, network, waffle } from 'hardhat'
import { MintableERC20, WETH9 } from '../../../types';
import { CompoundV3Protocol, makeProtocol } from '../shared/compoundV3Fixture';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals';
import { CometBrokerFixture, TestConfig1delta, cometBrokerFixture, initCometBroker } from '../shared/cometBrokerFixture.';
import { UniswapMinimalFixtureNoTokens, addLiquidity, uniswapMinimalFixtureNoTokens } from '../shared/uniswapFixture';
import { FeeAmount } from '../../uniswap-v3/periphery/shared/constants';
import { expect } from 'chai';
import { encodePath } from '../../uniswap-v3/periphery/shared/path';
import { MockProvider } from 'ethereum-waffle';
import { V2Fixture, uniV2Fixture } from '../shared/uniV2Fixture';


// we prepare a setup for compound in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('CompoundV3 Brokered Collateral Multi Swap operations', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let achi: SignerWithAddress;
    let wally: SignerWithAddress;
    let dennis: SignerWithAddress;
    let vlad: SignerWithAddress;
    let xander: SignerWithAddress;
    let test0: SignerWithAddress;
    let test1: SignerWithAddress;
    let test2: SignerWithAddress;
    let test3: SignerWithAddress;
    let uniswap: UniswapMinimalFixtureNoTokens;
    let compound: CompoundV3Protocol;
    let broker: CometBrokerFixture;
    let tokens: (MintableERC20 | WETH9)[];
    let provider: MockProvider
    let uniswapV2: V2Fixture


    before('Deploy Account, Trader, Uniswap and Compound', async () => {
        [deployer, alice, bob, carol, gabi, achi, wally, dennis,
            vlad, xander, test0, test1, test2, test3] = await ethers.getSigners();

        provider = waffle.provider;

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
                await tokens[i].connect(deployer).allocateTo(deployer.address, expandTo18Decimals(100_000_000))
                await tokens[i].connect(deployer).approve(compound.comet.address, expandTo18Decimals(100_000_000))
                await compound.comet.connect(deployer).supply(tokens[i].address, expandTo18Decimals(1_000_000))

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

                await compound.tokens[key].connect(bob).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(alice).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(carol).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(test1).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(test0).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(test2).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(gabi).approve(compound.comet.address, ethers.constants.MaxUint256)

                await compound.tokens[key].connect(deployer).transfer(carol.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(deployer).transfer(alice.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(deployer).transfer(gabi.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(deployer).transfer(xander.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(deployer).transfer(test0.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(deployer).transfer(test1.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(deployer).transfer(test2.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(xander).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(deployer).transfer(wally.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(wally).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(deployer).transfer(dennis.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(dennis).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(deployer).transfer(vlad.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(vlad).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(deployer).transfer(xander.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(xander).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(deployer).transfer(achi.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(achi).approve(compound.comet.address, ethers.constants.MaxUint256)
                await compound.tokens[key].connect(deployer).transfer(test2.address, expandTo18Decimals(1_000_000))
                await compound.tokens[key].connect(test2).approve(compound.comet.address, ethers.constants.MaxUint256)


            }
        }
        await broker.manager.approveRouter(tokens.map(t => t.address))
        await broker.manager.connect(deployer).approveComet(tokens.map(t => t.address), 0)
        await broker.manager.connect(deployer).addComet(compound.comet.address, 0)

        console.log("add liquidity AAVE USDC")
        await addLiquidity(
            deployer,
            compound.tokens["USDC"].address,
            compound.tokens["AAVE"].address,
            expandTo18Decimals(100_000),
            expandTo18Decimals(100_000),
            uniswap
        )
        console.log("add liquidity DAI AAVE")
        await addLiquidity(
            deployer,
            compound.tokens["DAI"].address,
            compound.tokens["AAVE"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity AAVE WETH")
        await addLiquidity(
            deployer,
            compound.tokens["AAVE"].address,
            compound.tokens["WETH"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(200),
            uniswap
        )

        console.log("add liquidity AAVE WMATIC")
        await addLiquidity(
            deployer,
            compound.tokens["AAVE"].address,
            compound.tokens["WMATIC"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity AAVE TEST1")
        await addLiquidity(
            deployer,
            compound.tokens["AAVE"].address,
            compound.tokens["TEST1"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )


        console.log("add liquidity TEST1 TEST2")
        await addLiquidity(
            deployer,
            compound.tokens["TEST1"].address,
            compound.tokens["TEST2"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity TEST2 DAI")
        await addLiquidity(
            deployer,
            compound.tokens["DAI"].address,
            compound.tokens["TEST2"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )
        console.log("add liquidity TEST2 USDC")
        await addLiquidity(
            deployer,
            compound.tokens["USDC"].address,
            compound.tokens["TEST2"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity WMATIC DAI")
        await addLiquidity(
            deployer,
            compound.tokens["DAI"].address,
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
            expandTo18Decimals(200),
            uniswap
        )
    })

    it('allows swap in supply exact in', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"

        const swapAmount = expandTo18Decimals(70)
        await compound.tokens[originIndex].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(98).div(100)
        }


        console.log("swap in")
        const balBefore = await compound.tokens[originIndex].balanceOf(carol.address)

        await broker.moneyMarket.connect(carol).swapAndSupplyExactIn(params)
        const balAfter = await compound.tokens[originIndex].balanceOf(carol.address)

        expect(swapAmount.toString()).to.equal(balBefore.sub(balAfter).toString())

        const cAfter = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[targetIndex].address)

        expect(Number(formatEther(cAfter))).to.greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.98)
        expect(Number(formatEther(cAfter))).to.lessThanOrEqual(Number(formatEther(swapAmount)))
    })

    it('allows swap Ether in supply exact in', async () => {

        const originIndex = "WETH"
        const targetIndex = "DAI"

        const swapAmount = expandTo18Decimals(1)
        await compound.tokens[originIndex].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["WMATIC"],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(95).div(100)
        }


        console.log("swap in")
        // const balBefore = await compound.tokens[originIndex].balanceOf(carol.address)
        const balBefore = await provider.getBalance(carol.address);
        const cBefore = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[targetIndex].address)
        const tx = await broker.moneyMarket.connect(carol).swapETHAndSupplyExactIn(params, { value: params.amountIn })
        // const balAfter = await compound.tokens[originIndex].balanceOf(carol.address)
        const balAfter = await provider.getBalance(carol.address);

        const receipt = await tx.wait();
        // here we receive ETH, but the transaction costs some, too - so we have to record and subtract that
        const gasUsed = (receipt.cumulativeGasUsed).mul(receipt.effectiveGasPrice);
        expect(swapAmount.add(gasUsed).toString()).to.equal(balBefore.sub(balAfter).toString())

        const cAfter = await compound.comet.collateralBalanceOf(carol.address, compound.tokens[targetIndex].address)

        expect(Number(formatEther(cAfter.sub(cBefore)))).to.greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.97)
        expect(Number(formatEther(cAfter.sub(cBefore)))).to.lessThanOrEqual(Number(formatEther(swapAmount)))
    })

    it('allows swap in supply exact out', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"

        const swapAmount = expandTo18Decimals(70)
        await compound.tokens[originIndex].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100),
            recipient: gabi.address,
        }


        console.log("swap in")
        const balBefore = await compound.tokens[originIndex].balanceOf(gabi.address)

        await broker.moneyMarket.connect(gabi).swapAndSupplyExactOut(params)
        const balAfter = await compound.tokens[originIndex].balanceOf(gabi.address)

        const cAfter = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[targetIndex].address)

        expect(swapAmount.toString()).to.equal(cAfter.toString())

        expect(Number(formatEther(swapAmount))).to.greaterThanOrEqual(Number(formatEther(balBefore.sub(balAfter))) * 0.98)
        expect(Number(formatEther(swapAmount))).to.lessThanOrEqual(Number(formatEther(balBefore.sub(balAfter))))
    })

    it('allows swap Ether and supply exact out', async () => {


        const originIndex = "WETH"
        const targetIndex = "DAI"

        const swapAmount = expandTo18Decimals(1)
        await compound.tokens[originIndex].connect(gabi).approve(broker.brokerProxy.address, constants.MaxUint256)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["WMATIC"],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(105).div(100),
            recipient: gabi.address,
        }

        const cBefore = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[targetIndex].address)
        console.log("swap in")
        // const balBefore = await compound.tokens[originIndex].balanceOf(gabi.address)
        const balBefore = await provider.getBalance(gabi.address);
        await broker.moneyMarket.connect(gabi).swapETHAndSupplyExactOut(params, { value: params.amountInMaximum })
        // const balAfter = await compound.tokens[originIndex].balanceOf(gabi.address)
        const balAfter = await provider.getBalance(gabi.address);


        const cAfter = await compound.comet.collateralBalanceOf(gabi.address, compound.tokens[targetIndex].address)

        expect(swapAmount.toString()).to.equal(cAfter.sub(cBefore).toString())

        expect(Number(formatEther(swapAmount))).to.greaterThanOrEqual(Number(formatEther(balBefore.sub(balAfter))) * 0.95)
        expect(Number(formatEther(swapAmount))).to.lessThanOrEqual(Number(formatEther(balBefore.sub(balAfter))))
    })

    it('allows wrap Ether and supply', async () => {
        const originIndex = "WETH"
        const targetIndex = "WETH"
        const swapAmount = BigNumber.from(10000)
        await compound.tokens[originIndex].connect(deployer).approve(broker.brokerProxy.address, constants.MaxUint256)

        const cBefore = await compound.comet.collateralBalanceOf(deployer.address, compound.tokens[targetIndex].address)
        console.log("wrap in")
        await broker.moneyMarket.connect(deployer).wrapAndSupply(0, { value: swapAmount })


        const cAfter = await compound.comet.collateralBalanceOf(deployer.address, compound.tokens[targetIndex].address)

        expect(cAfter.sub(cBefore)).to.equal(swapAmount)
    })

    it('allows withdraw and unwrap to Ether', async () => {
        const originIndex = "WETH"
        const targetIndex = "WETH"
        const swapAmount = BigNumber.from(10000)

        await compound.comet.connect(deployer).allow(broker.moneyMarket.address, true)

        await compound.tokens[originIndex].connect(deployer).approve(broker.brokerProxy.address, constants.MaxUint256)

        const cBefore = await compound.comet.collateralBalanceOf(deployer.address, compound.tokens[targetIndex].address)
        console.log("wrap out")
        await broker.moneyMarket.connect(deployer).withdrawAndUnwrap(swapAmount, deployer.address, 0)


        const cAfter = await compound.comet.collateralBalanceOf(deployer.address, compound.tokens[targetIndex].address)

        expect(cBefore.sub(cAfter)).to.equal(swapAmount)
    })

    it('allows withdraw and swap exact in', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"
        const supplied = expandTo18Decimals(100)
        const swapAmount = expandTo18Decimals(70)

        // supply
        await compound.comet.connect(achi).supply(compound.tokens[originIndex].address, supplied)
        // await compound.tokens[originIndex].connect(achi).approve(broker.brokerProxy.address, constants.MaxUint256)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountIn: swapAmount,
            recipient: achi.address,
            amountOutMinimum: swapAmount.mul(98).div(100)
        }

        await compound.comet.connect(achi).allow(broker.brokerProxy.address, true)

        const balBefore = await compound.tokens[targetIndex].balanceOf(achi.address)
        console.log("withdraw and swap exact in")
        await broker.moneyMarket.connect(achi).withdrawAndSwapExactIn(params)

        const balAfter = await compound.tokens[targetIndex].balanceOf(achi.address)

        const cAfter = await compound.comet.collateralBalanceOf(achi.address, compound.tokens[originIndex].address)

        expect(cAfter.toString()).to.equal(supplied.sub(swapAmount).toString())

        expect(Number(formatEther(swapAmount))).to.greaterThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
        expect(Number(formatEther(swapAmount))).to.lessThanOrEqual(Number(formatEther(balAfter.sub(balBefore))) * 1.03)
    })

    it('allows withdraw and swap all in', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"
        const supplied = expandTo18Decimals(100)

        // supply
        await compound.comet.connect(test0).supply(compound.tokens[originIndex].address, supplied)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            recipient: test0.address,
            amountOutMinimum: supplied.mul(95).div(100),
            cometId: 0
        }
        await compound.comet.connect(test0).allow(broker.brokerProxy.address, true)
        const balBefore = await compound.tokens[targetIndex].balanceOf(test0.address)
        console.log("withdraw and swap all in")
        await broker.moneyMarket.connect(test0).withdrawAndSwapAllIn(params)

        const balAfter = await compound.tokens[targetIndex].balanceOf(test0.address)

        const cAfter = await compound.comet.collateralBalanceOf(test0.address, compound.tokens[targetIndex].address)

        expect(cAfter.toString()).to.equal('0')

        expect(Number(formatEther(supplied))).to.greaterThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
        expect(Number(formatEther(supplied))).to.lessThanOrEqual(Number(formatEther(balAfter.sub(balBefore))) * 1.03)
    })

    it('allows withdraw and swap all in to ETH', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "WETH"
        const supplied = expandTo18Decimals(1)

        // supply
        await compound.comet.connect(test0).supply(compound.tokens[originIndex].address, supplied)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            recipient: test0.address,
            amountOutMinimum: supplied.mul(95).div(100),
            cometId: 0
        }

        await compound.comet.connect(test0).allow(broker.brokerProxy.address, true)
        const balBefore = await provider.getBalance(test0.address);
        console.log("withdraw and swap all in")
        await broker.moneyMarket.connect(test0).withdrawAndSwapAllInToETH(params)

        const balAfter = await provider.getBalance(test0.address);

        const cAfter = await compound.comet.collateralBalanceOf(test0.address, compound.tokens[targetIndex].address)

        expect(cAfter.toString()).to.equal('0')

        expect(Number(formatEther(supplied))).to.greaterThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
        expect(Number(formatEther(supplied))).to.lessThanOrEqual(Number(formatEther(balAfter.sub(balBefore))) * 1.03)
    })

    it('allows withdraw and swap exact out', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"
        const supplied = expandTo18Decimals(100)
        const swapAmount = expandTo18Decimals(70)

        // supply
        await compound.comet.connect(achi).supply(compound.tokens[originIndex].address, supplied)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100),
            recipient: achi.address,
        }

        await compound.comet.connect(achi).allow(broker.brokerProxy.address, true)

        const cBefore = await compound.comet.collateralBalanceOf(achi.address, compound.tokens[originIndex].address)
        const balBefore = await compound.tokens[targetIndex].balanceOf(achi.address)
        console.log("withdraw and swap exact out")
        await broker.moneyMarket.connect(achi).withdrawAndSwapExactOut(params)

        const balAfter = await compound.tokens[targetIndex].balanceOf(achi.address)

        const cAfter = await compound.comet.collateralBalanceOf(achi.address, compound.tokens[originIndex].address)


        expect(Number(formatEther(cAfter))).to.greaterThanOrEqual(
            Number(formatEther(cBefore.sub(swapAmount))) * 0.98)
        expect(Number(formatEther(cAfter))).to.lessThanOrEqual(
            Number(formatEther(cBefore.sub(swapAmount))))


        expect(swapAmount.toString()).to.equal(balAfter.sub(balBefore).toString())

    })

    it('allows borrow and swap exact in', async () => {

        const originIndex = "USDC"
        const supplyIndex = "AAVE"
        const targetIndex = "DAI"
        const providedAmount = expandTo18Decimals(160)
        const swapAmount = expandTo18Decimals(70)

        // supply
        await compound.comet.connect(wally).supply(compound.tokens[supplyIndex].address, providedAmount)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(98).div(100),
            recipient: wally.address,
        }

        const balBefore = await compound.tokens[targetIndex].balanceOf(wally.address)

        console.log("approve delegation")
        await compound.comet.connect(wally).allow(broker.brokerProxy.address, true)
        console.log("withdraw and swap exact in")
        await broker.moneyMarket.connect(wally).borrowAndSwapExactIn(params)

        const balAfter = await compound.tokens[targetIndex].balanceOf(wally.address)

        const dAfter = await compound.comet.borrowBalanceOf(wally.address)

        expect(dAfter.toString()).to.equal(swapAmount.toString())

        expect(Number(formatEther(swapAmount))).to.greaterThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
        expect(Number(formatEther(swapAmount)) * 0.98).to.lessThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
    })

    it('allows borrow and swap exact out', async () => {

        const originIndex = "USDC"
        const supplyIndex = "AAVE"
        const targetIndex = "DAI"
        const providedAmount = expandTo18Decimals(160)
        const swapAmount = expandTo18Decimals(70)

        // supply
        await compound.comet.connect(alice).supply(compound.tokens[supplyIndex].address, providedAmount)

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100),
            recipient: alice.address,
        }

        const balBefore = await compound.tokens[targetIndex].balanceOf(alice.address)


        console.log("approve delegation")
        await compound.comet.connect(alice).allow(broker.brokerProxy.address, true)

        await broker.moneyMarket.connect(alice).borrowAndSwapExactOut(params)

        const balAfter = await compound.tokens[targetIndex].balanceOf(alice.address)
        expect(swapAmount.toString()).to.equal(balAfter.sub(balBefore).toString())

        const dAfter = await compound.comet.borrowBalanceOf(alice.address)

        expect(Number(formatEther(dAfter))).to.greaterThanOrEqual(Number(formatEther(swapAmount)))
        expect(Number(formatEther(dAfter))).to.lessThanOrEqual(Number(formatEther(swapAmount)) * 1.03)
    })


    it('allows swap and repay exact in', async () => {

        const originIndex = "WMATIC"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "USDC"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(160)

        const swapAmount = expandTo18Decimals(70)
        const borrowAmount = expandTo18Decimals(75)

        // open position
        await compound.comet.connect(dennis).supply(compound.tokens[supplyIndex].address, providedAmount)


        console.log("borrow")
        await compound.comet.connect(dennis).withdraw(
            compound.tokens[borrowTokenIndex].address,
            borrowAmount,
        )

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountOutMinimum: swapAmount.mul(98).div(100),
            amountIn: swapAmount,
            recipient: dennis.address,
        }


        await compound.tokens[originIndex].connect(dennis).approve(broker.moneyMarket.address, constants.MaxUint256)



        const balBefore = await compound.tokens[originIndex].balanceOf(dennis.address)

        const dBefore = await compound.comet.borrowBalanceOf(dennis.address)
        console.log("swap and repay exact in")
        await broker.moneyMarket.connect(dennis).swapAndRepayExactIn(params)

        const balAfter = await compound.tokens[originIndex].balanceOf(dennis.address)

        const dAfter = await compound.comet.borrowBalanceOf(dennis.address)

        expect(balBefore.sub(balAfter).toString()).to.equal(swapAmount.toString())
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.98)
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)))
    })

    it('allows swap Ether and repay exact in', async () => {

        const originIndex = "WETH"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "USDC"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(160)

        const swapAmount = expandTo18Decimals(1)
        const borrowAmount = expandTo18Decimals(75)

        // open position
        await compound.comet.connect(dennis).supply(compound.tokens[supplyIndex].address, providedAmount)


        console.log("borrow")
        await compound.comet.connect(dennis).withdraw(
            compound.tokens[borrowTokenIndex].address,
            borrowAmount
        )

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["WMATIC"],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountOutMinimum: swapAmount.mul(95).div(100),
            amountIn: swapAmount,
            recipient: dennis.address,
        }


        await compound.tokens[originIndex].connect(dennis).approve(broker.moneyMarket.address, constants.MaxUint256)



        const balBefore = await provider.getBalance(dennis.address);

        const dBefore = await compound.comet.borrowBalanceOf(dennis.address)
        console.log("swap and repay exact in")
        const tx = await broker.moneyMarket.connect(dennis).swapETHAndRepayExactIn(params, { value: params.amountIn })
        const receipt = await tx.wait();
        // here we receive ETH, but the transaction costs some, too - so we have to record and subtract that
        const gasUsed = (receipt.cumulativeGasUsed).mul(receipt.effectiveGasPrice);

        const balAfter = await provider.getBalance(dennis.address)

        const dAfter = await compound.comet.borrowBalanceOf(dennis.address)

        expect(balBefore.sub(balAfter).sub(gasUsed).toString()).to.equal(swapAmount.toString())
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.95)
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)))
    })

    it('allows swap and repay exact out', async () => {

        const originIndex = "WMATIC"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "USDC"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(160)

        const swapAmount = expandTo18Decimals(70)
        const borrowAmount = expandTo18Decimals(75)

        // open position
        await compound.comet.connect(xander).supply(compound.tokens[supplyIndex].address, providedAmount)


        console.log("borrow")
        await compound.comet.connect(xander).withdraw(
            compound.tokens[borrowTokenIndex].address,
            borrowAmount
        )

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            amountOut: swapAmount,
            recipient: xander.address,
            amountInMaximum: swapAmount.mul(102).div(100)
        }


        await compound.tokens[originIndex].connect(xander).approve(broker.moneyMarket.address, constants.MaxUint256)



        const dBefore = await compound.comet.borrowBalanceOf(xander.address)
        const balBefore = await compound.tokens[originIndex].balanceOf(xander.address)

        console.log("swap and repay exact out")
        await broker.moneyMarket.connect(xander).swapAndRepayExactOut(params)

        const balAfter = await compound.tokens[originIndex].balanceOf(xander.address)

        const dAfter = await compound.comet.borrowBalanceOf(xander.address)
        // sometimes the debt accrues interest and minimally deviates, that is for safety
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.99999999)
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.00000001)

        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.99999999)
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.00000001)

        expect(Number(formatEther(balBefore.sub(balAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)))
        expect(Number(formatEther(balBefore.sub(balAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.02)
    })

    it('allows swap and repay all out', async () => {

        const originIndex = "WMATIC"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "USDC"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(160)
        const borrowAmount = expandTo18Decimals(75)

        // open position
        await compound.comet.connect(test1).supply(compound.tokens[supplyIndex].address, providedAmount)


        console.log("borrow")
        await compound.comet.connect(test1).withdraw(
            compound.tokens[borrowTokenIndex].address,
            borrowAmount
        )

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            cometId: 0,
            recipient: test1.address,
            amountInMaximum: borrowAmount.mul(105).div(100)
        }

        await compound.tokens[originIndex].connect(test1).approve(broker.moneyMarket.address, constants.MaxUint256)

        await compound.comet.connect(test1).allow(broker.brokerProxy.address, true)

        const balBefore = await compound.tokens[originIndex].balanceOf(test1.address)

        console.log("swap and repay all out")
        await broker.moneyMarket.connect(test1).swapAndRepayAllOut(params)

        const balAfter = await compound.tokens[originIndex].balanceOf(test1.address)
        const borrowBalAfter = await compound.comet.borrowBalanceOf(test1.address)
        // sometimes the debt accrues interest and minimally deviates, that is for safety
        expect(Number(formatEther(borrowBalAfter))).to.eq(0)

        expect(Number(formatEther(balBefore.sub(balAfter)))).to
            .greaterThanOrEqual(Number(formatEther(borrowAmount)))
        expect(Number(formatEther(balBefore.sub(balAfter)))).to
            .lessThanOrEqual(Number(formatEther(borrowAmount)) * 1.02)
    })

    it('allows swap Ether and repay exact out', async () => {

        const originIndex = "WETH"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "USDC"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(2)


        const swapAmount = expandTo18Decimals(1)
        const borrowAmount = expandTo18Decimals(1)

        // open position
        await compound.comet.connect(xander).supply(compound.tokens[supplyIndex].address, providedAmount)


        console.log("borrow")
        await compound.comet.connect(xander).withdraw(
            compound.tokens[borrowTokenIndex].address,
            borrowAmount
        )

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["WMATIC"],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            amountOut: swapAmount,
            recipient: xander.address,
            amountInMaximum: swapAmount.mul(110).div(100),
            cometId: 0
        }


        await compound.tokens[originIndex].connect(xander).approve(broker.moneyMarket.address, constants.MaxUint256)



        // const balBefore = await compound.tokens[originIndex].balanceOf(xander.address)
        const balBefore = await provider.getBalance(xander.address);

        const dBefore = await compound.comet.borrowBalanceOf(xander.address)
        console.log("swap and repay exact out")
        const tx = await broker.moneyMarket.connect(xander).swapETHAndRepayExactOut(params, { value: params.amountInMaximum })
        const receipt = await tx.wait();
        // here we receive ETH, but the transaction costs some, too - so we have to record and subtract that
        const gasUsed = (receipt.cumulativeGasUsed).mul(receipt.effectiveGasPrice);

        // const balAfter = await compound.tokens[originIndex].balanceOf(xander.address)
        const balAfter = await provider.getBalance(xander.address);


        const dAfter = await compound.comet.borrowBalanceOf(xander.address)
        // sometimes the debt accrues interest and minimally deviates, that is for safety
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.99999999)
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.00000001)

        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.99999999)
        expect(Number(formatEther(dBefore.sub(dAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.00000001)

        expect(Number(formatEther(balBefore.sub(balAfter).sub(gasUsed)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)))
        expect(Number(formatEther(balBefore.sub(balAfter).sub(gasUsed)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.07)
    })

    it('allows swap Ether and repay all out', async () => {

        const originIndex = "WETH"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "USDC"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(2)

        const borrowAmount = expandTo18Decimals(1)

        // open position
        await compound.comet.connect(test2).supply(compound.tokens[supplyIndex].address, providedAmount)


        console.log("borrow")
        await compound.comet.connect(test2).withdraw(
            compound.tokens[borrowTokenIndex].address,
            borrowAmount
        )

        let _tokensInRoute = [
            compound.tokens[originIndex],
            compound.tokens["WMATIC"],
            compound.tokens["AAVE"],
            compound.tokens["TEST1"],
            compound.tokens["TEST2"],
            compound.tokens[targetIndex]
        ].map(t => t.address)
        const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))

        const params = {
            path,
            recipient: test2.address,
            amountInMaximum: borrowAmount.mul(110).div(100),
            cometId: 0,
        }


        await compound.tokens[originIndex].connect(test2).approve(broker.moneyMarket.address, constants.MaxUint256)



        // const balBefore = await compound.tokens[originIndex].balanceOf(test2.address)
        const balBefore = await provider.getBalance(test2.address);

        console.log("swap and repay exact out")
        const tx = await broker.moneyMarket.connect(test2).swapETHAndRepayAllOut(params, { value: params.amountInMaximum })
        const receipt = await tx.wait();
        // here we receive ETH, but the transaction costs some, too - so we have to record and subtract that
        const gasUsed = (receipt.cumulativeGasUsed).mul(receipt.effectiveGasPrice);

        // const balAfter = await compound.tokens[originIndex].balanceOf(test2.address)
        const balAfter = await provider.getBalance(test2.address);

        const borrowAfter = await compound.comet.borrowBalanceOf(test2.address)
        // sometimes the debt accrues interest and minimally deviates, that is for safety
        expect(Number(formatEther(borrowAfter))).to.eq(0)

        expect(Number(formatEther(balBefore.sub(balAfter).sub(gasUsed)))).to
            .greaterThanOrEqual(Number(formatEther(borrowAmount)))
        expect(Number(formatEther(balBefore.sub(balAfter).sub(gasUsed)))).to
            .lessThanOrEqual(Number(formatEther(borrowAmount)) * 1.07)
    })

})


// ·----------------------------------------------------------------------------------------------|---------------------------|-----------|-----------------------------·
// |                                     Solc version: 0.8.15                                     ·  Optimizer enabled: true  ·  Runs: 1  ·  Block limit: 30000000 gas  │
// ·······························································································|···························|···········|······························
// |  Methods                                                                                                                                                           │
// ························································|······································|·············|·············|···········|···············|··············
// |  Contract                                             ·  Method                              ·  Min        ·  Max        ·  Avg      ·  # calls      ·  usd (avg)  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  borrowAndSwapExactIn                ·          -  ·          -  ·   426802  ·            1  ·      22.59  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  swapAndRepayExactIn                 ·          -  ·          -  ·   425997  ·            1  ·      22.55  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  swapAndSupplyExactIn                ·          -  ·          -  ·   523974  ·            1  ·      27.74  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  swapETHAndRepayExactIn              ·          -  ·          -  ·   451183  ·            2  ·      23.88  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  swapETHAndRepayExactOut             ·          -  ·          -  ·   437398  ·            2  ·      23.15  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  swapETHAndSupplyExactIn             ·          -  ·          -  ·   459244  ·            2  ·      24.31  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  swapETHAndSupplyExactOut            ·          -  ·          -  ·   430481  ·            1  ·      22.79  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  withdrawAndSwapExactIn              ·          -  ·          -  ·   392717  ·            1  ·      20.79  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  withdrawAndSwapExactOut             ·          -  ·          -  ·   358023  ·            1  ·      18.95  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  withdrawAndUnwrap                   ·          -  ·          -  ·    93708  ·            1  ·       4.96  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometMoneyMarketModule              ·  wrapAndSupply                       ·          -  ·          -  ·    84479  ·            1  ·       4.47  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometSweeperModule                  ·  withdrawAndSwapAllIn                ·          -  ·          -  ·   414334  ·            1  ·      21.93  │
// ·······································|······································|·············|·············|···········|···············|··············
// |  CometSweeperModule                  ·  withdrawAndSwapAllInToETH           ·          -  ·          -  ·   282604  ·            1  ·      14.96  │
// ·······································|······································|·············|·············|···········|···············|··············
