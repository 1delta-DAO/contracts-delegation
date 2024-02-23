import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { formatEther, parseUnits } from "ethers/lib/utils";
import { ConfigModule__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory, DeltaLendingInterfaceMantle__factory, ERC20Mock__factory, LensModule__factory, } from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
import { ModuleConfigAction, getSelectors } from "./libraries/diamond";
import { DeltaLendingInterfaceMantleInterface } from "../types/DeltaLendingInterfaceMantle";
const { ethers } = require("hardhat");

// block: 20240225
const MANTLE_CHAIN_ID = 5000;
const trader0 = '0x811e8f6d80F38A2f0f8b606cB743A950638f0aD4'
const admin = '0x999999833d965c275A2C102a4Ebf222ca938546f'

const strat = '0x5a093a9c4f440c6b105F0AF7f7C4f1fBE45567f9'
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"
const grai = '0x894134a25a5faC1c2C26F1d8fBf05111a3CB9487'

const brokerProxy = lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = lendleBrokerAddresses.MarginTraderModule[MANTLE_CHAIN_ID]
const lendingModule = lendleBrokerAddresses.LendingInterface[MANTLE_CHAIN_ID]
let multicaller: DeltaBrokerProxy
let flashAggregatorInterface: DeltaFlashAggregatorMantleInterface
let lendingInterfaceInterface: DeltaLendingInterfaceMantleInterface
let user: SignerWithAddress
let trader: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(user).attach(brokerProxy)
    flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
    lendingInterfaceInterface = DeltaLendingInterfaceMantle__factory.createInterface()

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


})

it("WMNT->USDC->STRAT exactIn (agni,stratum)", async function () {
    const amount = parseUnits('10', 18)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [strat])
    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)
    const tokencleo = await new ERC20Mock__factory(user).attach(strat)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, usdc, strat],
        [500, 0],
        [0, 0],
        [1, 56], // strat v
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amount, 0, path1])
    console.log("attempt swap")

    const balPre = await tokencleo.balanceOf(trader0)

    await multicaller.connect(impersonatedSigner).multicall([
        wrap,
        callSwap,
        sweep,
        // unwrap
    ],
        { value: amount })

    const balAfter = await tokencleo.balanceOf(trader0)
    console.log("receive", formatEther(balAfter.sub(balPre)))
    console.log("paid", formatEther(amount))
})


it("WMNT->USDC->STRAT exactOut (agni, strat_vola)", async function () {
    const amountIn = parseUnits('100', 18)
    const amount = parseUnits('0.041933248267840282', 18)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [strat])
    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const sweepWmnt = lendingInterfaceInterface.encodeFunctionData('sweep', [wmnt])
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)

    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, usdc, strat].reverse(),
        [500, 0].reverse(),
        [1, 1],
        [1, 56].reverse(), // celo, velo v
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amount, MaxUint128, path1])
    console.log("attempt swap")

    const tokenCleo = await new ERC20Mock__factory(user).attach(strat)
    const tokenWmnt = await new ERC20Mock__factory(user).attach(wmnt)
    const balPre = await tokenCleo.balanceOf(trader0)
    const balPreWmnt = await tokenWmnt.balanceOf(trader0)

    await multicaller.connect(impersonatedSigner).multicall([
        wrap,
        callSwap,
        sweep,
        sweepWmnt
    ],
        { value: amountIn })

    const balAfterWmnt = await tokenWmnt.balanceOf(trader0)

    const balAfter = await tokenCleo.balanceOf(trader0)
    console.log("receive", formatEther(balAfter.sub(balPre)))
    console.log("paid", formatEther(amountIn.sub(balAfterWmnt.sub(balPreWmnt))))
})

it("WMNT->USDC->USDT exactIn (agni,stratum_stable)", async function () {
    const amount = parseUnits('10', 18)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [usdt])
    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)
    const tokenUsdt = await new ERC20Mock__factory(user).attach(usdt)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, usdc, usdt],
        [500, 0],
        [0, 0],
        [1, 57], // strat v
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amount, 5e6, path1])
    console.log("attempt swap")

    const balPre = await tokenUsdt.balanceOf(trader0)

    await multicaller.connect(impersonatedSigner).multicall([
        wrap,
        callSwap,
        sweep,
        // unwrap
    ],
        { value: amount })

    const balAfter = await tokenUsdt.balanceOf(trader0)
    console.log("receive", balAfter.toString(), balPre.toString(), (balAfter.sub(balPre)).toString())
    console.log("paid", formatEther(amount))
})


it("WMNT->USDC->USDT exactOut (agni, strat_vola)", async function () {
    const amountIn = parseUnits('3', 18)
    const amountOut = parseUnits('1', 6)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [usdt])
    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const sweepWmnt = lendingInterfaceInterface.encodeFunctionData('sweep', [wmnt])
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)

    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, usdc, usdt].reverse(),
        [500, 0].reverse(),
        [1, 1],
        [1, 57].reverse(), // celo, velo v
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amountOut, MaxUint128, path1])
    console.log("attempt swap")

    const tokenCleo = await new ERC20Mock__factory(user).attach(usdt)
    const tokenWmnt = await new ERC20Mock__factory(user).attach(wmnt)
    const balPre = await tokenCleo.balanceOf(trader0)
    const balPreWmnt = await tokenWmnt.balanceOf(trader0)

    await multicaller.connect(impersonatedSigner).multicall([
        wrap,
        callSwap,
        sweep,
        sweepWmnt
    ],
        { value: amountIn })

    const balAfterWmnt = await tokenWmnt.balanceOf(trader0)

    const balAfter = await tokenCleo.balanceOf(trader0)
    console.log("receive", (balAfter.sub(balPre)).toString())
    console.log("paid", formatEther(amountIn.sub(balAfterWmnt.sub(balPreWmnt))))
})