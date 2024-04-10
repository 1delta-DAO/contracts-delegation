import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import {
    ConfigModule__factory,
    DeltaBrokerProxy,
    DeltaBrokerProxy__factory,
    DeltaFlashAggregatorMantle__factory,
    DeltaLendingInterfaceMantle__factory,
    LensModule__factory,
    StableDebtToken__factory,
} from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addressesLendleVTokens, addressesTokensMantle } from "../scripts/mantle/lendleAddresses";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount, MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
import { ModuleConfigAction, getSelectors } from "./libraries/diamond";
const { ethers } = require("hardhat");

// block: 20240225
const MANTLE_CHAIN_ID = 5000;
const admin = '0x999999833d965c275A2C102a4Ebf222ca938546f'

const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"

const brokerProxy = lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = lendleBrokerAddresses.MarginTraderModule[MANTLE_CHAIN_ID]
let multicaller: DeltaBrokerProxy
let flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
let lendingInterfaceInterface = DeltaLendingInterfaceMantle__factory.createInterface()
let user: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(user).attach(brokerProxy)

    console.log("deploy new aggregator")
    const newflashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).deploy()
    await impersonateAccount(admin)
    const impersonatedSigner = await ethers.getSigner(admin);
    console.log(impersonatedSigner.address)

    const config = await new ConfigModule__factory(impersonatedSigner).attach(brokerProxy)
    const lens = await new LensModule__factory(impersonatedSigner).attach(brokerProxy)

    const selectors = await lens.moduleFunctionSelectors(traderModule)
    await config.configureModules([{
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: selectors
    }])

    await config.configureModules([{
        moduleAddress: newflashAggregator.address,
        action: ModuleConfigAction.Add,
        functionSelectors: getSelectors(newflashAggregator)
    }])

})

it("Deposit", async function () {
    const amount = parseUnits('5000.0', 18)
    const callWrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const callDeposit = lendingInterfaceInterface.encodeFunctionData('deposit', [wmnt, user.address])

    await multicaller.connect(user).multicall([
        callWrap,
        callDeposit
    ], { value: amount })
})

it("Opens exact in", async function () {
    const amount = parseUnits('2.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, wmnt],
        [250],
        [6],
        [4], // Cleo
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Opens exact out", async function () {
    const amount = parseUnits('1.0', 18)
    const tokenIn = addressesTokensMantle.WMNT

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, usdc],
        [250],
        [3],
        [4], // Cleo
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Opens exact in multi", async function () {

    const amount = parseUnits('1.0', 6)
    const tokenIn = addressesTokensMantle.WMNT

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, weth, wmnt],
        [500, FeeAmount.LOW],
        [6, 0],
        [4, 0], // Cleo, fusionX
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Opens exact out multi", async function () {

    const amount = parseUnits('1.0', 18)

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, weth, usdc],
        [250, FeeAmount.LOW],
        [3, 1],
        [4, 51], // cleo, moe
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    await multicaller.connect(user).multicall([
        callSwap
    ])
})