import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { ethers, waffle } from 'hardhat'
import {
    MintableERC20,
    WETH9,
} from '../../../types';
import { FeeAmount } from '../../uniswap-v3/periphery/shared/constants';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals'
import { AaveBrokerFixtureInclV2, aaveBrokerFixtureInclV2, initAaveBroker } from '../shared/aaveBrokerFixture';
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
describe('Aave Money Market operations', async () => {
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

        await initAaveBroker(deployer, broker as any, aaveTest.pool.address)       // approve & fund wallets
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

        }

    })

    it('allows swap in supply exact in', async () => {

        const originIndex = "WMATIC"
        const targetIndex = "DAI"

        const swapAmount = expandTo18Decimals(70)
        await aaveTest.tokens[originIndex].connect(carol).approve(broker.brokerProxy.address, constants.MaxUint256)

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
        await broker.brokerProxy.connect(carol).multicall(
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

})
