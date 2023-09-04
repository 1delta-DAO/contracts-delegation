import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { ethers, waffle } from 'hardhat'
import {
    MintableERC20,
    WETH9,
} from '../../../types';
import { FeeAmount } from '../../uniswap-v3/periphery/shared/constants';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals'
import { initAaveBroker, AaveBrokerFixtureInclV2, aaveBrokerFixtureInclV2 } from '../shared/aaveBrokerFixture';
import { expect } from '../shared/expect'
import { initializeMakeSuite, InterestRateMode, AAVEFixture } from '../shared/aaveFixture';
import { addLiquidity, uniswapMinimalFixtureNoTokens, UniswapMinimalFixtureNoTokens } from '../shared/uniswapFixture';
import { formatEther } from 'ethers/lib/utils';
import { MockProvider } from 'ethereum-waffle';
import { uniV2Fixture, V2Fixture } from '../shared/uniV2Fixture';
import { encodeAggregatorPathEthers } from '../shared/aggregatorPath';

const DEPOSIT = 'deposit'
const WITHDRAW = 'withdraw'
const BORROW = 'borrow'
const REPAY = 'repay'

const WRAP = 'wrap'
const TRANSFER_IN = 'transferERC20In'
const TRANSFER_ALL_IN = 'transferERC20AllIn'
const SWAP_IN = 'swapExactInSpot'
const SWAP_ALL_IN = 'swapAllInSpot'
const SWAP_OUT = 'swapExactOutSpot'
const SWAP_ALL_OUT = 'swapAllOutSpot'
const SWAP_OUT_INTERNAL = 'swapExactOutSpotSelf'
const SWAP_ALL_OUT_INTERNAL = 'swapAllOutSpotSelf'
const SWEEP = 'sweep'
const UNWRAP = 'unwrap'

// we prepare a setup for aave in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('AAVE Money Market operations', async () => {
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
    let aaveTest: AAVEFixture;
    let broker: AaveBrokerFixtureInclV2;
    let tokens: (MintableERC20 | WETH9)[];
    let uniswapV2: V2Fixture
    let provider: MockProvider

    before('Deploy Account, Trader, Uniswap and AAVE', async () => {
        [deployer, alice, bob, carol, gabi, achi, wally, dennis,
            vlad, xander, test0, test1, test2, test3] = await ethers.getSigners();
        provider = waffle.provider;

        aaveTest = await initializeMakeSuite(deployer, 1)
        tokens = Object.values(aaveTest.tokens)
        uniswap = await uniswapMinimalFixtureNoTokens(deployer, aaveTest.tokens["WETH"].address)
        uniswapV2 = await uniV2Fixture(deployer, aaveTest.tokens["WETH"].address)
        broker = await aaveBrokerFixtureInclV2(deployer, uniswap.factory.address, aaveTest.pool.address, uniswapV2.factoryV2.address, aaveTest.tokens["WETH"].address)

        await initAaveBroker(deployer, broker as any, uniswap, aaveTest)

        await broker.manager.setUniswapRouter(uniswap.router.address)
        // approve & fund wallets
        let keys = Object.keys(aaveTest.tokens)
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i]
            await aaveTest.tokens[key].connect(deployer).approve(aaveTest.pool.address, constants.MaxUint256)
            if (key === "WETH") {
                await (aaveTest.tokens[key] as WETH9).deposit({ value: expandTo18Decimals(5_000) })
                await aaveTest.pool.connect(deployer).supply(aaveTest.tokens[key].address, expandTo18Decimals(2_000), deployer.address, 0)

            } else {
                await (aaveTest.tokens[key] as MintableERC20)['mint(address,uint256)'](deployer.address, expandTo18Decimals(100_000_000_000))
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

                await aaveTest.tokens[key].connect(deployer).transfer(xander.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(xander).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(deployer).transfer(wally.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(wally).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(deployer).transfer(dennis.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(dennis).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(deployer).transfer(vlad.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(vlad).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(deployer).transfer(xander.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(xander).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(deployer).transfer(achi.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(achi).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(deployer).transfer(test2.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(test2).approve(aaveTest.pool.address, ethers.constants.MaxUint256)

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
            await broker.manager.approveRouter([token.address])

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

        console.log("add liquidity AAVE TEST1")
        await addLiquidity(
            deployer,
            aaveTest.tokens["AAVE"].address,
            aaveTest.tokens["TEST1"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )


        console.log("add liquidity TEST1 TEST2")
        await addLiquidity(
            deployer,
            aaveTest.tokens["TEST1"].address,
            aaveTest.tokens["TEST2"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity TEST2 DAI")
        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
            aaveTest.tokens["TEST2"].address,
            expandTo18Decimals(1_000_000),
            expandTo18Decimals(1_000_000),
            uniswap
        )

        console.log("add liquidity WMATIC DAI")
        await addLiquidity(
            deployer,
            aaveTest.tokens["DAI"].address,
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
            expandTo18Decimals(200),
            uniswap
        )
    })

    it('allows swap in supply exact in', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"

        const swapAmount = expandTo18Decimals(70)
        await aaveTest.tokens[originIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address)
        // const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [0, 0, 0, 0], // action
            [1, 2, 1, 1], // pid
            2 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(98).div(100)
        }
        const callTransfer = broker.moneyMarket.interface.encodeFunctionData(TRANSFER_IN, [aaveTest.tokens[originIndex].address, swapAmount])
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_IN, [
            params.amountIn,
            params.amountOutMinimum,
            params.path
        ]
        )
        const callDeposit = broker.moneyMarket.interface.encodeFunctionData(DEPOSIT,
            [
                aaveTest.tokens[targetIndex].address,
                carol.address,
            ])
        console.log("swap in")
        const balBefore = await aaveTest.tokens[originIndex].balanceOf(carol.address)
        await broker.brokerProxy.connect(carol).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callTransfer,
                callSwap,
                callDeposit
            ]
        )
        // await broker.moneyMarket.connect(carol).swapAndSupplyExactIn(params)
        const balAfter = await aaveTest.tokens[originIndex].balanceOf(carol.address)
        const aTokenBal = await aaveTest.aTokens[targetIndex].balanceOf(carol.address)

        expect(swapAmount.toString()).to.equal(balBefore.sub(balAfter).toString())

        expect(Number(formatEther(aTokenBal))).to.greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.98)
        expect(Number(formatEther(aTokenBal))).to.lessThanOrEqual(Number(formatEther(swapAmount)))
    })

    it('allows swap Ether in supply exact in', async () => {

        const originIndex = "WETH"
        const targetIndex = "DAI"

        const swapAmount = expandTo18Decimals(1)
        await aaveTest.tokens[originIndex].connect(carol).approve(broker.broker.address, constants.MaxUint256)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["WMATIC"],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address)
        // const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [0, 0, 0, 0, 0], // action
            [1, 2, 1, 1, 1], // pid
            2 // flag
        )
        const params = {
            path,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(95).div(100)
        }

        const callTransfer = broker.moneyMarket.interface.encodeFunctionData(WRAP,)
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_IN, [
            params.amountIn,
            params.amountOutMinimum,
            params.path
        ]
        )
        const callDeposit = broker.moneyMarket.interface.encodeFunctionData(DEPOSIT,
            [
                aaveTest.tokens[targetIndex].address,
                carol.address,
            ]
        )

        console.log("swap in")
        // const balBefore = await aaveTest.tokens[originIndex].balanceOf(carol.address)
        const balBefore = await provider.getBalance(carol.address);
        const aTokenBalBefore = await aaveTest.aTokens[targetIndex].balanceOf(carol.address)
        // const tx = await broker.moneyMarket.connect(carol).swapETHAndSupplyExactIn(params, { value: params.amountIn })
        const tx = await broker.brokerProxy.connect(carol).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callTransfer,
                callSwap,
                callDeposit
            ],
            { value: swapAmount }
        )
        // const balAfter = await aaveTest.tokens[originIndex].balanceOf(carol.address)
        const balAfter = await provider.getBalance(carol.address);

        const aTokenBal = await aaveTest.aTokens[targetIndex].balanceOf(carol.address)
        const receipt = await tx.wait();
        // here we receive ETH, but the transaction costs some, too - so we have to record and subtract that
        const gasUsed = (receipt.cumulativeGasUsed).mul(receipt.effectiveGasPrice);
        expect(swapAmount.add(gasUsed).toString()).to.equal(balBefore.sub(balAfter).toString())

        expect(Number(formatEther(aTokenBal.sub(aTokenBalBefore)))).to.greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.97)
        expect(Number(formatEther(aTokenBal.sub(aTokenBalBefore)))).to.lessThanOrEqual(Number(formatEther(swapAmount)))
    })

    it('allows swap in supply exact out', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"

        const swapAmount = expandTo18Decimals(70)
        await aaveTest.tokens[originIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address).reverse()
        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [1, 1, 1, 1], // action
            [1, 2, 1, 1], // pid
            99 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100),
            recipient: gabi.address,
        }


        console.log("swap in")
        const balBefore = await aaveTest.tokens[originIndex].balanceOf(gabi.address)
        const callTransfer = broker.moneyMarket.interface.encodeFunctionData(TRANSFER_IN, [aaveTest.tokens[originIndex].address, params.amountInMaximum])
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_OUT, [
            params.amountOut,
            params.amountInMaximum,
            params.path
        ]
        )
        const callDeposit = broker.moneyMarket.interface.encodeFunctionData(DEPOSIT,
            [
                aaveTest.tokens[targetIndex].address,
                gabi.address,
            ]
        )
        const callSweep = broker.moneyMarket.interface.encodeFunctionData(SWEEP, [aaveTest.tokens[originIndex].address])
        // await broker.moneyMarket.connect(gabi).swapAndSupplyExactOut(params)
        await broker.brokerProxy.connect(gabi).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                // callTransfer,
                callSwap,
                callDeposit,
                // callSweep
            ],
        )
        const balAfter = await aaveTest.tokens[originIndex].balanceOf(gabi.address)
        const aTokenBal = await aaveTest.aTokens[targetIndex].balanceOf(gabi.address)

        expect(swapAmount.toString()).to.equal(aTokenBal.toString())

        expect(Number(formatEther(swapAmount))).to.greaterThanOrEqual(Number(formatEther(balBefore.sub(balAfter))) * 0.98)
        expect(Number(formatEther(swapAmount))).to.lessThanOrEqual(Number(formatEther(balBefore.sub(balAfter))))
    })

    it('allows swap Ether and supply exact out', async () => {


        const originIndex = "WETH"
        const targetIndex = "DAI"

        const swapAmount = expandTo18Decimals(1)
        await aaveTest.tokens[originIndex].connect(gabi).approve(broker.broker.address, constants.MaxUint256)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["WMATIC"],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address).reverse()

        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [1, 1, 1, 1, 1], // action
            [1, 1, 2, 1, 1], // pid
            99 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(105).div(100),
            recipient: gabi.address,
        }


        console.log("swap in")
        // const balBefore = await aaveTest.tokens[originIndex].balanceOf(gabi.address)
        const aTokenBalBefore = await aaveTest.aTokens[targetIndex].balanceOf(gabi.address)
        const balBefore = await provider.getBalance(gabi.address);

        const callWrap = broker.moneyMarket.interface.encodeFunctionData(WRAP,)
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_OUT_INTERNAL, [
            params.amountOut,
            params.amountInMaximum,
            params.path
        ]
        )
        const callDeposit = broker.moneyMarket.interface.encodeFunctionData(DEPOSIT,
            [
                aaveTest.tokens[targetIndex].address,
                gabi.address,
            ]
        )
        const callSweep = broker.moneyMarket.interface.encodeFunctionData(UNWRAP,)

        // await broker.moneyMarket.connect(gabi).swapETHAndSupplyExactOut(params, { value: params.amountInMaximum })

        await broker.brokerProxy.connect(gabi).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callWrap,
                callSwap,
                callDeposit,
                callSweep
            ],
            { value: params.amountInMaximum }
        )
        // const balAfter = await aaveTest.tokens[originIndex].balanceOf(gabi.address)
        const balAfter = await provider.getBalance(gabi.address);
        const aTokenBal = await aaveTest.aTokens[targetIndex].balanceOf(gabi.address)

        expect(swapAmount.toString()).to.equal(aTokenBal.sub(aTokenBalBefore).toString())

        expect(Number(formatEther(swapAmount))).to.greaterThanOrEqual(Number(formatEther(balBefore.sub(balAfter))) * 0.95)
        expect(Number(formatEther(swapAmount))).to.lessThanOrEqual(Number(formatEther(balBefore.sub(balAfter))))
    })

    it('allows withdraw and swap exact in', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"
        const supplied = expandTo18Decimals(100)
        const swapAmount = expandTo18Decimals(70)

        // supply
        await aaveTest.pool.connect(achi).supply(aaveTest.tokens[originIndex].address, supplied, achi.address, 0)
        // await aaveTest.tokens[originIndex].connect(achi).approve(broker.broker.address, constants.MaxUint256)
        await aaveTest.aTokens[originIndex].connect(achi).approve(broker.broker.address, constants.MaxUint256)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address)
        // const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [0, 0, 0, 0], // action
            [1, 2, 1, 1], // pid
            2 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(98).div(100),
            recipient: achi.address,
        }

        const callTransfer = broker.moneyMarket.interface.encodeFunctionData(TRANSFER_IN, [aaveTest.aTokens[originIndex].address, swapAmount])
        const callWithdraw = broker.moneyMarket.interface.encodeFunctionData(WITHDRAW, [aaveTest.tokens[originIndex].address, broker.brokerProxy.address])
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_IN, [
            params.amountIn,
            params.amountOutMinimum,
            params.path
        ]
        )
        const callSweep = broker.moneyMarket.interface.encodeFunctionData(SWEEP, [aaveTest.tokens[targetIndex].address])
        const balBefore = await aaveTest.tokens[targetIndex].balanceOf(achi.address)
        console.log("withdraw and swap exact in")
        // await broker.moneyMarket.connect(achi).withdrawAndSwapExactIn(params)
        await broker.brokerProxy.connect(achi).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callTransfer,
                callWithdraw,
                callSwap,
                callSweep
            ],
        )

        const balAfter = await aaveTest.tokens[targetIndex].balanceOf(achi.address)
        const bb = await aaveTest.pool.getUserAccountData(achi.address)
        expect(bb.totalCollateralBase.toString()).to.equal(supplied.sub(swapAmount).toString())

        expect(Number(formatEther(swapAmount))).to.greaterThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
        expect(Number(formatEther(swapAmount))).to.lessThanOrEqual(Number(formatEther(balAfter.sub(balBefore))) * 1.03)
    })

    it('allows withdraw and swap all in', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"
        const supplied = expandTo18Decimals(100)

        // supply
        await aaveTest.pool.connect(test0).supply(aaveTest.tokens[originIndex].address, supplied, test0.address, 0)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address)
        // const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [0, 0, 0, 0], // action
            [1, 2, 1, 1], // pid
            2 // flag
        )
        const params = {
            path,
            recipient: test0.address,
            amountOutMinimum: supplied.mul(95).div(100)
        }


        const callTransfer = broker.moneyMarket.interface.encodeFunctionData(TRANSFER_ALL_IN, [aaveTest.aTokens[originIndex].address])
        const callWithdraw = broker.moneyMarket.interface.encodeFunctionData(WITHDRAW, [
            aaveTest.tokens[originIndex].address,
            broker.brokerProxy.address
        ])
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_ALL_IN, [
            params.amountOutMinimum,
            params.path
        ]
        )
        const callSweep = broker.moneyMarket.interface.encodeFunctionData(SWEEP, [aaveTest.tokens[targetIndex].address])

        await aaveTest.aTokens[originIndex].connect(test0).approve(broker.moneyMarket.address, ethers.constants.MaxUint256)
        const ba = await aaveTest.aTokens[originIndex].balanceOf(test0.address)
        const balBefore = await aaveTest.tokens[targetIndex].balanceOf(test0.address)
        console.log("withdraw and swap all in")
        // await broker.moneyMarket.connect(test0).withdrawAndSwapAllIn(params)
        await broker.brokerProxy.connect(test0).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callTransfer,
                callWithdraw,
                callSwap,
                callSweep
            ],
        )

        const balAfter = await aaveTest.tokens[targetIndex].balanceOf(test0.address)
        const balAfterCollateral = await aaveTest.aTokens[originIndex].balanceOf(test0.address)
        const bb = await aaveTest.pool.getUserAccountData(test0.address)
        expect(balAfterCollateral.toString()).to.equal('0')

        expect(Number(formatEther(supplied))).to.greaterThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
        expect(Number(formatEther(supplied))).to.lessThanOrEqual(Number(formatEther(balAfter.sub(balBefore))) * 1.03)
    })

    it('allows withdraw and swap all in to ETH', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "WETH"
        const supplied = expandTo18Decimals(1)

        // supply
        await aaveTest.pool.connect(test0).supply(aaveTest.tokens[originIndex].address, supplied, test0.address, 0)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address)
        // const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [0, 0,], // action
            [1, 2,], // pid
            2 // flag
        )
        const params = {
            path,
            recipient: test0.address,
            amountOutMinimum: supplied.mul(95).div(100)
        }
        const callTransfer = broker.moneyMarket.interface.encodeFunctionData(TRANSFER_ALL_IN, [aaveTest.aTokens[originIndex].address])
        const callWithdraw = broker.moneyMarket.interface.encodeFunctionData(WITHDRAW, [
            aaveTest.tokens[originIndex].address,
            broker.brokerProxy.address
        ])
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_ALL_IN, [
            params.amountOutMinimum,
            params.path
        ]
        )
        const callSweep = broker.moneyMarket.interface.encodeFunctionData(UNWRAP,)

        await aaveTest.aTokens[originIndex].connect(test0).approve(broker.moneyMarket.address, ethers.constants.MaxUint256)
        const ba = await aaveTest.aTokens[originIndex].balanceOf(test0.address)
        console.log("test", ba.toString())
        const balBefore = await provider.getBalance(test0.address);
        console.log("withdraw and swap all in")
        // await broker.moneyMarket.connect(test0).withdrawAndSwapAllInToETH(params)
        await broker.brokerProxy.connect(test0).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callTransfer,
                callWithdraw,
                callSwap,
                callSweep
            ],
        )
        const balAfter = await provider.getBalance(test0.address);
        const balAfterCollateral = await aaveTest.aTokens[originIndex].balanceOf(test0.address)

        expect(balAfterCollateral.toString()).to.equal('0')

        expect(Number(formatEther(supplied))).to.greaterThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
        expect(Number(formatEther(supplied))).to.lessThanOrEqual(Number(formatEther(balAfter.sub(balBefore))) * 1.03)
    })

    it('allows withdraw and swap exact out', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"
        const supplied = expandTo18Decimals(100)
        const swapAmount = expandTo18Decimals(70)

        // supply
        await aaveTest.pool.connect(achi).supply(aaveTest.tokens[originIndex].address, supplied, achi.address, 0)
        await aaveTest.aTokens[originIndex].connect(achi).approve(broker.broker.address, constants.MaxUint256)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address).reverse()
        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [1, 1, 1, 1], // action
            [1, 2, 1, 1], // pid
            3 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100),
            recipient: achi.address,
        }

        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_OUT, [
            params.amountOut,
            params.amountInMaximum,
            params.path
        ]
        )
        const callSweep = broker.moneyMarket.interface.encodeFunctionData(SWEEP, [aaveTest.tokens[targetIndex].address])


        const balBefore = await aaveTest.tokens[targetIndex].balanceOf(achi.address)
        const bbBefore = await aaveTest.pool.getUserAccountData(achi.address)
        console.log("withdraw and swap exact out")
        // await broker.moneyMarket.connect(achi).withdrawAndSwapExactOut(params)
        await broker.brokerProxy.connect(achi).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                // callTransfer,
                // callWithdraw,
                callSwap,
                callSweep
            ],
        )
        const balAfter = await aaveTest.tokens[targetIndex].balanceOf(achi.address)
        const bb = await aaveTest.pool.getUserAccountData(achi.address)

        expect(Number(formatEther(bb.totalCollateralBase))).to.greaterThanOrEqual(Number(formatEther(bbBefore.totalCollateralBase.sub(swapAmount))) * 0.98)
        expect(Number(formatEther(bb.totalCollateralBase))).to.lessThanOrEqual(Number(formatEther(bbBefore.totalCollateralBase.sub(swapAmount))))


        expect(swapAmount.toString()).to.equal(balAfter.sub(balBefore).toString())

    })

    it('allows borrow and swap exact in', async () => {

        const originIndex = "WMATIC"
        const supplyIndex = "AAVE"
        const targetIndex = "DAI"
        const providedAmount = expandTo18Decimals(160)
        const swapAmount = expandTo18Decimals(70)

        // supply
        await aaveTest.pool.connect(wally).supply(aaveTest.tokens[supplyIndex].address, providedAmount, wally.address, 0)
        await aaveTest.pool.connect(wally).setUserUseReserveAsCollateral(aaveTest.tokens[supplyIndex].address, true)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address)
        // const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [0, 0, 0, 0], // action
            [1, 2, 1, 1], // pid
            2 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountIn: swapAmount,
            amountOutMinimum: swapAmount.mul(98).div(100),
            recipient: wally.address,
        }

        const callBorrow = broker.moneyMarket.interface.encodeFunctionData(BORROW, [
            aaveTest.tokens[originIndex].address,
            swapAmount,
            InterestRateMode.VARIABLE
        ])
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_IN, [
            params.amountIn,
            params.amountOutMinimum,
            params.path
        ]
        )
        const callSweep = broker.moneyMarket.interface.encodeFunctionData(SWEEP, [aaveTest.tokens[targetIndex].address])

        const balBefore = await aaveTest.tokens[targetIndex].balanceOf(wally.address)

        console.log("approve delegation")
        await aaveTest.vTokens[originIndex].connect(wally).approveDelegation(broker.moneyMarket.address, constants.MaxUint256)

        console.log("withdraw and swap exact in")
        // await broker.moneyMarket.connect(wally).borrowAndSwapExactIn(params)
        await broker.brokerProxy.connect(wally).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callBorrow,
                callSwap,
                callSweep
            ],
        )

        const balAfter = await aaveTest.tokens[targetIndex].balanceOf(wally.address)
        const bb = await aaveTest.pool.getUserAccountData(wally.address)

        expect(bb.totalDebtBase.toString()).to.equal(swapAmount.toString())

        expect(Number(formatEther(swapAmount))).to.greaterThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
        expect(Number(formatEther(swapAmount)) * 0.98).to.lessThanOrEqual(Number(formatEther(balAfter.sub(balBefore))))
    })

    it('allows borrow and swap exact out', async () => {

        const originIndex = "WMATIC"
        const supplyIndex = "AAVE"
        const targetIndex = "DAI"
        const providedAmount = expandTo18Decimals(160)
        const swapAmount = expandTo18Decimals(70)

        // supply
        await aaveTest.pool.connect(alice).supply(aaveTest.tokens[supplyIndex].address, providedAmount, alice.address, 0)
        await aaveTest.pool.connect(alice).setUserUseReserveAsCollateral(aaveTest.tokens[supplyIndex].address, true)

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address).reverse()
        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [1, 1, 1, 1], // action
            [1, 2, 1, 1], // pid
            2 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOut: swapAmount,
            amountInMaximum: swapAmount.mul(102).div(100),
            recipient: alice.address,
        }


        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_OUT, [
            params.amountOut,
            params.amountInMaximum,
            params.path
        ]
        )
        const callSweep = broker.moneyMarket.interface.encodeFunctionData(SWEEP, [aaveTest.tokens[targetIndex].address])

        const balBefore = await aaveTest.tokens[targetIndex].balanceOf(alice.address)

        console.log("approve delegation")
        await aaveTest.vTokens[originIndex].connect(alice).approveDelegation(broker.moneyMarket.address, constants.MaxUint256)

        console.log("withdraw and swap exact in")
        // await broker.moneyMarket.connect(alice).borrowAndSwapExactOut(params)
        await broker.brokerProxy.connect(alice).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callSwap,
                callSweep
            ],
        )

        const balAfter = await aaveTest.tokens[targetIndex].balanceOf(alice.address)
        const bb = await aaveTest.pool.getUserAccountData(alice.address)
        expect(swapAmount.toString()).to.equal(balAfter.sub(balBefore).toString())

        expect(Number(formatEther(bb.totalDebtBase))).to.greaterThanOrEqual(Number(formatEther(swapAmount)))
        expect(Number(formatEther(bb.totalDebtBase))).to.lessThanOrEqual(Number(formatEther(swapAmount)) * 1.03)
    })


    it('allows swap and repay exact in', async () => {

        const originIndex = "WMATIC"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "DAI"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(160)

        const swapAmount = expandTo18Decimals(70)
        const borrowAmount = expandTo18Decimals(75)

        // open position
        await aaveTest.pool.connect(dennis).supply(aaveTest.tokens[supplyIndex].address, providedAmount, dennis.address, 0)
        await aaveTest.pool.connect(dennis).setUserUseReserveAsCollateral(aaveTest.tokens[supplyIndex].address, true)


        console.log("borrow")
        await aaveTest.pool.connect(dennis).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            dennis.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address)
        // const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [0, 0, 0, 0], // action
            [1, 2, 1, 1], // pid
            2 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOutMinimum: swapAmount.mul(98).div(100),
            amountIn: swapAmount,
            recipient: dennis.address,
        }

        const callTransfer = broker.moneyMarket.interface.encodeFunctionData(TRANSFER_IN, [aaveTest.tokens[originIndex].address, swapAmount])

        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_IN, [
            params.amountIn,
            params.amountOutMinimum,
            params.path
        ]
        )

        const callRepay = broker.moneyMarket.interface.encodeFunctionData(REPAY, [
            aaveTest.tokens[targetIndex].address,
            dennis.address,
            InterestRateMode.VARIABLE
        ])


        await aaveTest.tokens[originIndex].connect(dennis).approve(broker.moneyMarket.address, constants.MaxUint256)

        await aaveTest.aTokens[borrowTokenIndex].connect(dennis).approve(broker.broker.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(dennis).approveDelegation(broker.broker.address, constants.MaxUint256)

        const balBefore = await aaveTest.tokens[originIndex].balanceOf(dennis.address)
        const bbBefore = await aaveTest.pool.getUserAccountData(dennis.address)

        console.log("swap and repay exact in")
        // await broker.moneyMarket.connect(dennis).swapAndRepayExactIn(params)
        await broker.brokerProxy.connect(dennis).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callTransfer,
                callSwap,
                callRepay
            ],
        )

        const balAfter = await aaveTest.tokens[originIndex].balanceOf(dennis.address)
        const bb = await aaveTest.pool.getUserAccountData(dennis.address)

        expect(balBefore.sub(balAfter).toString()).to.equal(swapAmount.toString())
        expect(Number(formatEther(bbBefore.totalDebtBase.sub(bb.totalDebtBase)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.98)
        expect(Number(formatEther(bbBefore.totalDebtBase.sub(bb.totalDebtBase)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)))
    })

    it('allows swap Ether and repay exact in', async () => {

        const originIndex = "WETH"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "DAI"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(160)

        const swapAmount = expandTo18Decimals(1)
        const borrowAmount = expandTo18Decimals(75)

        // open position
        await aaveTest.pool.connect(dennis).supply(aaveTest.tokens[supplyIndex].address, providedAmount, dennis.address, 0)
        await aaveTest.pool.connect(dennis).setUserUseReserveAsCollateral(aaveTest.tokens[supplyIndex].address, true)


        console.log("borrow")
        await aaveTest.pool.connect(dennis).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            dennis.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["WMATIC"],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address)
        // const path = encodePath(_tokensInRoute, new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [0, 0, 0, 0, 0], // action
            [1, 2, 1, 1, 1], // pid
            2 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOutMinimum: swapAmount.mul(95).div(100),
            amountIn: swapAmount,
            recipient: dennis.address,
        }

        const callWrap = broker.moneyMarket.interface.encodeFunctionData(WRAP,)

        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_IN, [
            params.amountIn,
            params.amountOutMinimum,
            params.path
        ]
        )

        const callRepay = broker.moneyMarket.interface.encodeFunctionData(REPAY, [
            aaveTest.tokens[targetIndex].address,
            dennis.address,
            InterestRateMode.VARIABLE
        ])


        await aaveTest.tokens[originIndex].connect(dennis).approve(broker.moneyMarket.address, constants.MaxUint256)

        await aaveTest.aTokens[borrowTokenIndex].connect(dennis).approve(broker.broker.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(dennis).approveDelegation(broker.broker.address, constants.MaxUint256)

        const balBefore = await provider.getBalance(dennis.address);
        const bbBefore = await aaveTest.pool.getUserAccountData(dennis.address)

        console.log("swap and repay exact in")
        // const tx = await broker.moneyMarket.connect(dennis).swapETHAndRepayExactIn(params, { value: params.amountIn })
        const tx = await broker.brokerProxy.connect(dennis).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callWrap,
                callSwap,
                callRepay
            ],
            { value: swapAmount }
        )

        const receipt = await tx.wait();
        // here we receive ETH, but the transaction costs some, too - so we have to record and subtract that
        const gasUsed = (receipt.cumulativeGasUsed).mul(receipt.effectiveGasPrice);

        const balAfter = await provider.getBalance(dennis.address)
        const bb = await aaveTest.pool.getUserAccountData(dennis.address)

        expect(balBefore.sub(balAfter).sub(gasUsed).toString()).to.equal(swapAmount.toString())
        expect(Number(formatEther(bbBefore.totalDebtBase.sub(bb.totalDebtBase)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.95)
        expect(Number(formatEther(bbBefore.totalDebtBase.sub(bb.totalDebtBase)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)))
    })

    it('allows swap and repay exact out', async () => {

        const originIndex = "WMATIC"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "DAI"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(160)

        const swapAmount = expandTo18Decimals(70)
        const borrowAmount = expandTo18Decimals(75)

        // open position
        await aaveTest.pool.connect(xander).supply(aaveTest.tokens[supplyIndex].address, providedAmount, xander.address, 0)
        await aaveTest.pool.connect(xander).setUserUseReserveAsCollateral(aaveTest.tokens[supplyIndex].address, true)

        console.log("borrow")
        await aaveTest.pool.connect(xander).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            xander.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address).reverse()
        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [1, 1, 1, 1], // action
            [1, 2, 1, 1], // pid
            99 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            amountOut: swapAmount,
            recipient: xander.address,
            amountInMaximum: swapAmount.mul(102).div(100)
        }

        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_OUT, [
            params.amountOut,
            params.amountInMaximum,
            params.path
        ]
        )

        const callRepay = broker.moneyMarket.interface.encodeFunctionData(REPAY, [
            aaveTest.tokens[targetIndex].address,
            xander.address,
            InterestRateMode.VARIABLE
        ])

        await aaveTest.tokens[originIndex].connect(xander).approve(broker.moneyMarket.address, constants.MaxUint256)

        const balBefore = await aaveTest.tokens[originIndex].balanceOf(xander.address)
        const vBalBefore = await aaveTest.vTokens[borrowTokenIndex].balanceOf(xander.address)
        const bbBefore = await aaveTest.pool.getUserAccountData(xander.address)

        console.log("swap and repay exact out")
        // await broker.moneyMarket.connect(xander).swapAndRepayExactOut(params)
        await broker.brokerProxy.connect(xander).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callSwap,
                callRepay
            ]
        )

        const balAfter = await aaveTest.tokens[originIndex].balanceOf(xander.address)
        const vBalAfter = await aaveTest.vTokens[borrowTokenIndex].balanceOf(xander.address)
        const bb = await aaveTest.pool.getUserAccountData(xander.address)

        // sometimes the debt accrues interest and minimally deviates, that is for safety
        expect(Number(formatEther(vBalBefore.sub(vBalAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.99999999)
        expect(Number(formatEther(vBalBefore.sub(vBalAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.00000001)

        expect(Number(formatEther(bbBefore.totalDebtBase.sub(bb.totalDebtBase)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.99999999)
        expect(Number(formatEther(bbBefore.totalDebtBase.sub(bb.totalDebtBase)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.00000001)

        expect(Number(formatEther(balBefore.sub(balAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)))
        expect(Number(formatEther(balBefore.sub(balAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.02)
    })

    it('allows swap and repay all out', async () => {

        const originIndex = "WMATIC"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "DAI"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(160)
        const borrowAmount = expandTo18Decimals(75)

        // open position
        await aaveTest.pool.connect(test1).supply(aaveTest.tokens[supplyIndex].address, providedAmount, test1.address, 0)
        await aaveTest.pool.connect(test1).setUserUseReserveAsCollateral(aaveTest.tokens[supplyIndex].address, true)


        console.log("borrow")
        await aaveTest.pool.connect(test1).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            test1.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address).reverse()
        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [1, 1, 1, 1], // action
            [1, 2, 1, 1], // pid
            99 // flag
        )
        const params = {
            path,
            interestRateMode: InterestRateMode.VARIABLE,
            recipient: test1.address,
            amountInMaximum: borrowAmount.mul(105).div(100)
        }

        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_ALL_OUT, [
            params.amountInMaximum,
            InterestRateMode.VARIABLE,
            params.path
        ]
        )
        const callRepay = broker.moneyMarket.interface.encodeFunctionData(REPAY, [
            aaveTest.tokens[targetIndex].address,
            test1.address,
            InterestRateMode.VARIABLE
        ])
        await aaveTest.tokens[originIndex].connect(test1).approve(broker.moneyMarket.address, constants.MaxUint256)

        await aaveTest.aTokens[borrowTokenIndex].connect(test1).approve(broker.broker.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(test1).approveDelegation(broker.broker.address, constants.MaxUint256)

        const balBefore = await aaveTest.tokens[originIndex].balanceOf(test1.address)
        const vBalBefore = await aaveTest.vTokens[borrowTokenIndex].balanceOf(test1.address)
        const bbBefore = await aaveTest.pool.getUserAccountData(test1.address)

        console.log("swap and repay all out")
        // await broker.moneyMarket.connect(test1).swapAllOutSpot(params.amountInMaximum, params.interestRateMode, params.path)
        await broker.brokerProxy.connect(test1).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callSwap,
                callRepay
            ]
        )
        const balAfter = await aaveTest.tokens[originIndex].balanceOf(test1.address)
        const vBalAfter = await aaveTest.vTokens[borrowTokenIndex].balanceOf(test1.address)
        const bb = await aaveTest.pool.getUserAccountData(test1.address)

        // sometimes the debt accrues interest and minimally deviates, that is for safety
        expect(Number(formatEther(vBalAfter))).to.eq(0)
        expect(Number(formatEther(bb.totalDebtBase))).to.eq(0)

        expect(Number(formatEther(balBefore.sub(balAfter)))).to
            .greaterThanOrEqual(Number(formatEther(borrowAmount)))
        expect(Number(formatEther(balBefore.sub(balAfter)))).to
            .lessThanOrEqual(Number(formatEther(borrowAmount)) * 1.02)
    })

    it('allows swap Ether and repay exact out', async () => {

        const originIndex = "WETH"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "DAI"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(2)


        const swapAmount = expandTo18Decimals(1)
        const borrowAmount = expandTo18Decimals(1)

        // open position
        await aaveTest.pool.connect(xander).supply(aaveTest.tokens[supplyIndex].address, providedAmount, xander.address, 0)
        await aaveTest.pool.connect(xander).setUserUseReserveAsCollateral(aaveTest.tokens[supplyIndex].address, true)


        console.log("borrow")
        await aaveTest.pool.connect(xander).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            xander.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["WMATIC"],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address).reverse()
        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [1, 1, 1, 1, 1], // action
            [1, 2, 1, 1, 1], // pid
            99 // flag
        )
        const params = {
            path,
            amountOut: swapAmount,
            recipient: xander.address,
            amountInMaximum: swapAmount.mul(110).div(100),
            interestRateMode: InterestRateMode.VARIABLE,
        }

        const callWrap = broker.moneyMarket.interface.encodeFunctionData(WRAP,)
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_OUT_INTERNAL, [
            params.amountOut,
            params.amountInMaximum,
            params.path
        ]
        )
        const callRepay = broker.moneyMarket.interface.encodeFunctionData(REPAY, [
            aaveTest.tokens[targetIndex].address,
            xander.address,
            InterestRateMode.VARIABLE
        ])
        const callUnwrap = broker.moneyMarket.interface.encodeFunctionData(UNWRAP,)

        await aaveTest.tokens[originIndex].connect(xander).approve(broker.moneyMarket.address, constants.MaxUint256)

        await aaveTest.aTokens[borrowTokenIndex].connect(xander).approve(broker.broker.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(xander).approveDelegation(broker.broker.address, constants.MaxUint256)

        // const balBefore = await aaveTest.tokens[originIndex].balanceOf(xander.address)
        const balBefore = await provider.getBalance(xander.address);
        const vBalBefore = await aaveTest.vTokens[borrowTokenIndex].balanceOf(xander.address)
        const bbBefore = await aaveTest.pool.getUserAccountData(xander.address)

        console.log("swap and repay exact out")
        // const tx = await broker.moneyMarket.connect(xander).swapETHAndRepayExactOut(params, { value: params.amountInMaximum })
        const tx = await broker.brokerProxy.connect(xander).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callWrap,
                callSwap,
                callUnwrap,
                callRepay
            ],
            { value: params.amountInMaximum }
        )
        const receipt = await tx.wait();
        // here we receive ETH, but the transaction costs some, too - so we have to record and subtract that
        const gasUsed = (receipt.cumulativeGasUsed).mul(receipt.effectiveGasPrice);

        // const balAfter = await aaveTest.tokens[originIndex].balanceOf(xander.address)
        const balAfter = await provider.getBalance(xander.address);

        const vBalAfter = await aaveTest.vTokens[borrowTokenIndex].balanceOf(xander.address)
        const bb = await aaveTest.pool.getUserAccountData(xander.address)

        // sometimes the debt accrues interest and minimally deviates, that is for safety
        expect(Number(formatEther(vBalBefore.sub(vBalAfter)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.99999999)
        expect(Number(formatEther(vBalBefore.sub(vBalAfter)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.00000001)

        expect(Number(formatEther(bbBefore.totalDebtBase.sub(bb.totalDebtBase)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)) * 0.99999999)
        expect(Number(formatEther(bbBefore.totalDebtBase.sub(bb.totalDebtBase)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.00000001)

        expect(Number(formatEther(balBefore.sub(balAfter).sub(gasUsed)))).to
            .greaterThanOrEqual(Number(formatEther(swapAmount)))
        expect(Number(formatEther(balBefore.sub(balAfter).sub(gasUsed)))).to
            .lessThanOrEqual(Number(formatEther(swapAmount)) * 1.07)
    })

    it('allows swap Ether and repay all out', async () => {

        const originIndex = "WETH"
        const supplyIndex = "AAVE"
        const borrowTokenIndex = "DAI"
        const targetIndex = borrowTokenIndex
        const providedAmount = expandTo18Decimals(2)

        const borrowAmount = expandTo18Decimals(1)

        // open position
        await aaveTest.pool.connect(test2).supply(aaveTest.tokens[supplyIndex].address, providedAmount, test2.address, 0)
        await aaveTest.pool.connect(test2).setUserUseReserveAsCollateral(aaveTest.tokens[supplyIndex].address, true)


        console.log("borrow")
        await aaveTest.pool.connect(test2).borrow(
            aaveTest.tokens[borrowTokenIndex].address,
            borrowAmount,
            InterestRateMode.VARIABLE,
            0,
            test2.address
        )

        let _tokensInRoute = [
            aaveTest.tokens[originIndex],
            aaveTest.tokens["WMATIC"],
            aaveTest.tokens["AAVE"],
            aaveTest.tokens["TEST1"],
            aaveTest.tokens["TEST2"],
            aaveTest.tokens[targetIndex]
        ].map(t => t.address).reverse()
        // const path = encodePath(_tokensInRoute.reverse(), new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM))
        const path = encodeAggregatorPathEthers(
            _tokensInRoute,
            new Array(_tokensInRoute.length - 1).fill(FeeAmount.MEDIUM),
            [1, 1, 1, 1, 1], // action
            [1, 2, 1, 1, 1], // pid
            99 // flag
        )
        const params = {
            path,
            recipient: test2.address,
            amountInMaximum: borrowAmount.mul(110).div(100),
            interestRateMode: InterestRateMode.VARIABLE
        }

        const callWrap = broker.moneyMarket.interface.encodeFunctionData(WRAP,)
        const callSwap = broker.moneyMarket.interface.encodeFunctionData(SWAP_ALL_OUT_INTERNAL, [
            params.amountInMaximum,
            InterestRateMode.VARIABLE,
            params.path
        ]
        )
        const callRepay = broker.moneyMarket.interface.encodeFunctionData(REPAY, [
            aaveTest.tokens[targetIndex].address,
            test2.address,
            InterestRateMode.VARIABLE
        ])

        const callUnwrap = broker.moneyMarket.interface.encodeFunctionData(UNWRAP,)

        await aaveTest.tokens[originIndex].connect(test2).approve(broker.moneyMarket.address, constants.MaxUint256)

        await aaveTest.aTokens[borrowTokenIndex].connect(test2).approve(broker.broker.address, constants.MaxUint256)

        await aaveTest.vTokens[borrowTokenIndex].connect(test2).approveDelegation(broker.broker.address, constants.MaxUint256)

        // const balBefore = await aaveTest.tokens[originIndex].balanceOf(test2.address)
        const balBefore = await provider.getBalance(test2.address);
        const vBalBefore = await aaveTest.vTokens[borrowTokenIndex].balanceOf(test2.address)
        const bbBefore = await aaveTest.pool.getUserAccountData(test2.address)

        console.log("swap and repay exact out")
        // const tx = await broker.moneyMarket.connect(test2).swapETHAndRepayAllOut(params,
        //     { value: params.amountInMaximum })

        const tx = await broker.brokerProxy.connect(test2).multicallSingleModule(broker.moneyMarketImplementation.address,
            [
                callWrap,
                callSwap,
                callRepay,
                callUnwrap,
            ],
            { value: params.amountInMaximum }
        )
        const receipt = await tx.wait();
        // here we receive ETH, but the transaction costs some, too - so we have to record and subtract that
        const gasUsed = (receipt.cumulativeGasUsed).mul(receipt.effectiveGasPrice);

        // const balAfter = await aaveTest.tokens[originIndex].balanceOf(test2.address)
        const balAfter = await provider.getBalance(test2.address);

        const vBalAfter = await aaveTest.vTokens[borrowTokenIndex].balanceOf(test2.address)
        const bb = await aaveTest.pool.getUserAccountData(test2.address)

        // sometimes the debt accrues interest and minimally deviates, that is for safety
        expect(Number(formatEther(vBalAfter))).to.eq(0)

        expect(Number(formatEther(bb.totalDebtBase))).to.eq(0)
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
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  borrowAndSwapExactIn                ·          -  ·          -  ·   569775  ·            1  ·      13.84  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  borrowAndSwapExactOut               ·          -  ·          -  ·   532559  ·            1  ·      12.94  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  swapAndRepayExactIn                 ·          -  ·          -  ·   486497  ·            1  ·      11.82  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  swapAndRepayExactOut                ·          -  ·          -  ·   463454  ·            1  ·      11.26  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  swapAndSupplyExactIn                ·          -  ·          -  ·   574986  ·            1  ·      13.97  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  swapAndSupplyExactOut               ·          -  ·          -  ·   477796  ·            1  ·      11.61  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  swapETHAndRepayExactIn              ·          -  ·          -  ·   526377  ·            2  ·      12.79  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  swapETHAndRepayExactOut             ·          -  ·          -  ·   519547  ·            2  ·      12.62  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  swapETHAndSupplyExactIn             ·          -  ·          -  ·   523035  ·            2  ·      12.71  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  swapETHAndSupplyExactOut            ·          -  ·          -  ·   492247  ·            1  ·      11.96  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  withdrawAndSwapExactIn              ·          -  ·          -  ·   518645  ·            1  ·      12.60  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVEMoneyMarketModule                                ·  withdrawAndSwapExactOut             ·          -  ·          -  ·   470759  ·            1  ·      11.44  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  swapAndRepayAllOut                  ·          -  ·          -  ·   473672  ·            1  ·      11.51  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  swapETHAndRepayAllOut               ·          -  ·          -  ·   529257  ·            2  ·      12.86  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  withdrawAndSwapAllIn                ·          -  ·          -  ·   503422  ·            1  ·      12.23  │
// ························································|······································|·············|·············|···········|···············|··············
// |  AAVESweeperModule                                    ·  withdrawAndSwapAllInToETH           ·          -  ·          -  ·   375522  ·            1  ·       9.12  │
// ························································|······································|·············|·············|···········|···············|··············7

// ························································|······································|·············|·············|·············|···············|··············
// |  DeltaBrokerProxy                                     ·  multicallSingleModule               ·     367802  ·     565994  ·     492302  ·           18  ·      12.08  │
// ························································|······································|·············|·············|·············|···············|··············
