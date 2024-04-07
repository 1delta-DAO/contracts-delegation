import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { formatEther, parseUnits } from "ethers/lib/utils";
import {
    AToken__factory,
    ConfigModule__factory,
    DeltaBrokerProxy,
    DeltaBrokerProxy__factory,
    DeltaFlashAggregatorMantle__factory,
    DeltaLendingInterfaceMantle__factory,
    LensModule__factory,
    MockERC20__factory,
    OneDeltaQuoterMantle,
    OneDeltaQuoterMantle__factory, StableDebtToken__factory, WETH9__factory,
} from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addressesLendleVTokens, addressesTokensMantle, addressesLendleATokens } from '../scripts/mantle/lendleAddresses';
import { encodeAggregatorPathEthers, encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
import { MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
import { ModuleConfigAction, getSelectors } from "./libraries/diamond";
import { expect } from "chai";
import { ethers } from "hardhat";

// block: 20240225
const MANTLE_CHAIN_ID = 5000;
const admin = '0x999999833d965c275A2C102a4Ebf222ca938546f'

const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const usde = '0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34'
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"

const brokerProxy = lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = lendleBrokerAddresses.MarginTraderModule[MANTLE_CHAIN_ID]
const lendingModule = lendleBrokerAddresses.LendingInterface[MANTLE_CHAIN_ID]
let multicaller: DeltaBrokerProxy
let flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
let lendingInterfaceInterface = DeltaLendingInterfaceMantle__factory.createInterface()
let user: SignerWithAddress
let quoter: OneDeltaQuoterMantle
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    quoter = await new OneDeltaQuoterMantle__factory(signer).deploy()
    multicaller = await new DeltaBrokerProxy__factory(user).attach(brokerProxy)

    console.log("deploy new aggregator")
    const newflashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).deploy()
    const newLendingInterface = await new DeltaLendingInterfaceMantle__factory(signer).deploy()


    await impersonateAccount(admin)
    const impersonatedSigner = await ethers.getSigner(admin);
    console.log(impersonatedSigner.address)

    const config = await new ConfigModule__factory(impersonatedSigner).attach(brokerProxy)
    const lens = await new LensModule__factory(impersonatedSigner).attach(brokerProxy)

    const selectors = await lens.moduleFunctionSelectors(traderModule)
    const selectorsLending = await lens.moduleFunctionSelectors(lendingModule)

    await config.configureModules([{
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: selectors
    },
    {
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: selectorsLending
    },
    {
        moduleAddress: newflashAggregator.address,
        action: ModuleConfigAction.Add,
        functionSelectors: getSelectors(newflashAggregator)
    },
    {
        moduleAddress: newLendingInterface.address,
        action: ModuleConfigAction.Add,
        functionSelectors: getSelectors(newLendingInterface)
    }])
})

it("Deposit", async function () {
    const amount = parseUnits('3.0', 18)
    const callWrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const callDeposit = lendingInterfaceInterface.encodeFunctionData('deposit' as any, [wmnt, user.address])

    await multicaller.connect(user).multicall([
        callWrap,
        callDeposit
    ], { value: amount })
})

it("Opens exact in, CLEO->LB", async function () {
    const amount = parseUnits('2.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, usde, usdt],
        [100, 1],
        [6, 0],
        [4, 103], // Cleo, MoeLB
        2
    )

    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Opens exact in, Agni->3USD->LB->CLEO", async function () {
    const amount = parseUnits('2.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdt, usdc, usdt, usde, usdc],
        [100, 0, 1, 100],
        [6, 0, 0, 0],
        [1, 102, 103, 4], // Agni, Stratum3USD MoeLB Cleo
        2
    )

    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Closes exact in, CLEO->LB->3USD->Agni", async function () {
    const amount = parseUnits('1.0', 6)

    const collateralToken = await new AToken__factory(user).attach(addressesLendleATokens.USDC)
    await collateralToken.approve(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdt, usdc, usdt, usde, usdc].reverse(),
        [100, 0, 1, 100].reverse(),
        [8, 0, 0, 0],
        [1, 102, 103, 4].reverse(), // Agni, Stratum3USD MoeLB Cleo
        5
    )

    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Closes exact out, LB->CLEO", async function () {
    const amount = parseUnits('0.70', 6)

    const collateralToken = await new AToken__factory(user).attach(addressesLendleATokens.USDT)
    await collateralToken.approve(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, usde, usdt],
        [100, 1],
        [5, 1],
        [4, 103], // Cleo MoeLB
        5
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ],
    )
})

it("Opens exact out CLEO->LB", async function () {
    const amount = parseUnits('1.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, usde, usdt],
        [100, 1],
        [3, 1],
        [4, 103], // Cleo Moe
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Swap exact out Linear", async function () {

    const amountOut = parseUnits('1.0', 18)
    const amountDepo = parseUnits('100', 18)
    const tokenIn = addressesTokensMantle.WMNT

    const wmntContract = await new WETH9__factory(user).attach(wmnt)
    await wmntContract.deposit({ value: amountDepo })

    await wmntContract.approve(multicaller.address, MaxUint128)

    const usdeContract = await new MockERC20__factory(user).attach(usde)
    const balanceInBefore = await wmntContract.balanceOf(user.address)
    const balanceOutBefore = await usdeContract.balanceOf(user.address)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usde, usdt, weth, wmnt],
        [1, 0, 0],
        [3, 1, 1],
        [103, 51, 56], // Moe LB, Moe V1, Stratum
        99
    )

    const pathQuoter = encodeQuoterPathEthers(
        [usde, usdt, weth, wmnt],
        [1, 0, 0],
        [103, 51, 56], // Moe LB, Moe V1, Stratum
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        pathQuoter, amountOut
    )

    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactOutSpot', [amountOut, MaxUint128, path1])
    const callSweep = lendingInterfaceInterface.encodeFunctionData('sweep', [usde])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap,
        callSweep
    ])
    const balanceInAfter = await wmntContract.balanceOf(user.address)
    const balanceOutAfter = await usdeContract.balanceOf(user.address)
    // pulled the quoted amount
    expect(quote.toString()).to.equal(balanceInBefore.sub(balanceInAfter))
    const received = Number(formatEther(balanceOutAfter.sub(balanceOutBefore)))
    const amountOutNumber = Number(formatEther(amountOut))
    // received the expected amount or slightly more
    expect(received).to.be.greaterThanOrEqual(received)
    // also doe not deviate too much from the expected out amount
    expect(amountOutNumber).to.approximately(received, 1e-6)
})
