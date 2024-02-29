import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import {
    ConfigModule__factory,
    DeltaBrokerProxy,
    DeltaBrokerProxy__factory,
    DeltaFlashAggregatorMantle__factory,
    DeltaLendingInterfaceMantle__factory,
    LensModule__factory,
    ERC20Mock__factory,
    OneDeltaQuoterMantle,
    OneDeltaQuoterMantle__factory,
    ManagementModule__factory,
} from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { encodeAggregatorPathEthers, encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
import { ModuleConfigAction, getSelectors } from "./libraries/diamond";
import { DeltaLendingInterfaceMantleInterface } from "../types/DeltaLendingInterfaceMantle";
import { constants } from "ethers";
import { findBalanceSlot, getSlot } from "./1delta/shared/forkUtils";
import { expandToDecimals } from "./1delta/shared/misc";
import { expect } from "chai";
const { ethers } = require("hardhat");

// block: 20240225
const MANTLE_CHAIN_ID = 5000;
const trader0 = '0xaffe73AA5EBd0CD95D89ab9fa2512Fc9e2d3289b'
const admin = '0x999999833d965c275A2C102a4Ebf222ca938546f'

const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"
const USDY = '0x5bE26527e817998A7206475496fDE1E68957c5A6';
const MUSD = '0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3';
const STRATUM_3POOL = '0xD6F312AA90Ad4C92224436a7A4a648d69482e47e';

const brokerProxy = lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = lendleBrokerAddresses.MarginTraderModule[MANTLE_CHAIN_ID]
const lendingModule = lendleBrokerAddresses.LendingInterface[MANTLE_CHAIN_ID]

let multicaller: DeltaBrokerProxy
let flashAggregatorInterface: DeltaFlashAggregatorMantleInterface
let lendingInterfaceInterface: DeltaLendingInterfaceMantleInterface
let user: SignerWithAddress
let quoter: OneDeltaQuoterMantle
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(user).attach(brokerProxy)
    flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
    lendingInterfaceInterface = DeltaLendingInterfaceMantle__factory.createInterface()
    quoter = await new OneDeltaQuoterMantle__factory(signer).deploy()

    console.log("deploy new aggregator")
    const newflashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).deploy()
    console.log("deploy new lending interface")
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


    const management = await new ManagementModule__factory(impersonatedSigner).attach(brokerProxy)
    await management.approveAddress([usdc, usdt, MUSD], STRATUM_3POOL)
    await management.approveAddress([USDY], MUSD)

    const tokenUsdc = await new ERC20Mock__factory(user).attach(usdc)
    // automatically find mapping slot
    const mappingSlot = await findBalanceSlot(tokenUsdc)
    console.log("Found USDC.balanceOf slot: ", mappingSlot)

    // calculate balanceOf[signerAddress] slot
    const signerBalanceSlot = getSlot(trader0, mappingSlot)

    const depositBalance = expandToDecimals(100000, 6)
    // console.log("SLot", signerBalanceSlot)
    // set it to the value
    const value: any = Number(depositBalance.toString())
    console.log("Change bal", signerBalanceSlot)
    await ethers.provider.send(
        "hardhat_setStorageAt",
        [
            usdc,
            signerBalanceSlot.replace('0x0', '0x'),
            ethers.utils.hexlify(ethers.utils.zeroPad(value, 32))
        ]
    )

})

it.only("USDC->USDT 3USD", async function () {
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)
    const tokenIn = await new ERC20Mock__factory(impersonatedSigner).attach(usdc)
    const amountIn = parseUnits('2', 6)
    const route = encodeQuoterPathEthers(
        [usdc, usdt],
        [0],
        [102]
    )
    const quote = await quoter.connect(impersonatedSigner).callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("quote", quote.toString())
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, usdt],
        [0],
        [0],
        [102], // strat v
        99
    )
    await tokenIn.connect(impersonatedSigner).approve(brokerProxy, constants.MaxUint256)
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amountIn, '0', path1])
    console.log("attempt swap")

    const tokenOut = await new ERC20Mock__factory(impersonatedSigner).attach(usdt)
    const balPre = await tokenOut.balanceOf(trader0)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [usdt])
    const transferIn = lendingInterfaceInterface.encodeFunctionData('transferERC20In', [tokenIn.address, amountIn])
    await multicaller.connect(impersonatedSigner).multicall([
        transferIn,
        callSwap,
        sweep,
        // unwrap
    ])

    const balAfter = await tokenOut.balanceOf(trader0)
    console.log("receive", (balAfter.sub(balPre)).toString())
    expect((balAfter.sub(balPre)).toString()).to.equal(quote.toString())
})


it.only("USDC->USDY 3USD", async function () {
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)
    const tokenIn = await new ERC20Mock__factory(impersonatedSigner).attach(usdc)
    const amountIn = parseUnits('2', 6)
    const route = encodeQuoterPathEthers(
        [usdc, USDY],
        [0],
        [102]
    )
    const quote = await quoter.connect(impersonatedSigner).callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("quote", quote.toString())
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, USDY],
        [0],
        [0],
        [102], // strat v
        99
    )
    await tokenIn.connect(impersonatedSigner).approve(brokerProxy, constants.MaxUint256)
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amountIn, '0', path1])
    console.log("attempt swap")

    const tokenOut = await new ERC20Mock__factory(impersonatedSigner).attach(USDY)
    const balPre = await tokenOut.balanceOf(trader0)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [USDY])
    const transferIn = lendingInterfaceInterface.encodeFunctionData('transferERC20In', [tokenIn.address, amountIn])
    await multicaller.connect(impersonatedSigner).multicall([
        transferIn,
        callSwap,
        sweep,
        // unwrap
    ])

    const balAfter = await tokenOut.balanceOf(trader0)
    console.log("receive", (balAfter.sub(balPre)).toString())
    expect((balAfter.sub(balPre)).gte(quote)).to.equal(true)
})

it.only("USDY->USDT 3USD", async function () {
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)
    const tokenIn = await new ERC20Mock__factory(impersonatedSigner).attach(USDY)
    const amountIn = parseUnits('0.1', 18)
    const route = encodeQuoterPathEthers(
        [USDY, usdt],
        [0],
        [102]
    )
    const quote = await quoter.connect(impersonatedSigner).callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("quote", quote.toString())
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [USDY, usdt],
        [0],
        [0],
        [102], // strat usd
        99
    )
    await tokenIn.connect(impersonatedSigner).approve(brokerProxy, constants.MaxUint256)
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amountIn, '0', path1])
    console.log("attempt swap")

    const tokenOut = await new ERC20Mock__factory(impersonatedSigner).attach(usdt)
    const balPre = await tokenOut.balanceOf(trader0)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [usdt])
    const transferIn = lendingInterfaceInterface.encodeFunctionData('transferERC20In', [tokenIn.address, amountIn])
    await multicaller.connect(impersonatedSigner).multicall([
        transferIn,
        callSwap,
        sweep,
    ])

    const balAfter = await tokenOut.balanceOf(trader0)
    console.log("receive", (balAfter.sub(balPre)).toString())
    expect((balAfter.sub(balPre)).toString()).to.equal(quote.toString())
})
