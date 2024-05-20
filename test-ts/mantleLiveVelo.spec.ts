import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import { ConfigModule__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory, DeltaLendingInterfaceMantle__factory, LensModule__factory, StableDebtToken__factory, } from "../types";
import { ONE_DELTA_ADDRESSES } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { LENDLE_V_TOKENS, addressesTokensMantle } from "../scripts/mantle/addresses/lendleAddresses";
import { encodeAggregatorPathEthersMargin } from "./1delta/shared/aggregatorPath";
import { FeeAmount, MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
import { ModuleConfigAction, getSelectors } from "./libraries/diamond";
import { DeltaLendingInterfaceMantleInterface } from "../types/DeltaLendingInterfaceMantle";
const { ethers } = require("hardhat");


// block: 20240225
const MANTLE_CHAIN_ID = 5000;
const trader0 = '0xaffe73AA5EBd0CD95D89ab9fa2512Fc9e2d3289b'
const admin = '0x999999833d965c275A2C102a4Ebf222ca938546f'

const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const wbtc = "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"

const brokerProxy = ONE_DELTA_ADDRESSES.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = ONE_DELTA_ADDRESSES.MarginTraderModule[MANTLE_CHAIN_ID]
const lendingModule = ONE_DELTA_ADDRESSES.LendingInterface[MANTLE_CHAIN_ID]
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

it("Deposit", async function () {
    const amount = parseUnits('5000.0', 18)
    const callWrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const callDeposit = lendingInterfaceInterface.encodeFunctionData('deposit', [wmnt, user.address, 0])

    await multicaller.connect(user).multicall([
        callWrap,
        callDeposit
    ], { value: amount })
})

it("USDT->USDC exactIn (velo_stable)", async function () {
    const amount = parseUnits('2.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [usdt, usdc],
        [0],
        [6],
        [53], // Velo Stable
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})



it("USDT->USDC exactOut (velo_stable)", async function () {
    const amount = parseUnits('1.0', 6)
    const tokenIn = addressesTokensMantle.WMNT

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [usdc, usdt],
        [FeeAmount.MEDIUM],
        [3],
        [53], // Velo Stable
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])

})

it("USDC->WMNT->WETH exactIn (velo_volatile, fusionx_v2)", async function () {

    const amount = parseUnits('1.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [usdc, wmnt, weth],
        [0, FeeAmount.LOW],
        [6, 0],
        [52, 51], // Velo Volatile, fusionX
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})


it("USDC->WMNT->WETH exactOut (velo_volatile, butter)", async function () {

    const amount = parseUnits('0.0001', 18)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [weth, wmnt, usdc],
        [FeeAmount.LOW, FeeAmount.LOW],
        [3, 1],
        [3, 52], // butter, Velo volatile
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("WBTC->USDC->USDT exactOut (velo_stable, velo_volatile)", async function () {

    const amount = parseUnits('0.0001', 8)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [wbtc, usdc, usdt],
        [FeeAmount.LOW, FeeAmount.LOW],
        [3, 1],
        [52, 53], // Velo volatile, velo stable
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("WBTC->USDC->USDT exactIn (velo_vola, velo_stable)", async function () {

    const amount = parseUnits('10', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.WBTC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [wbtc, usdc, usdt].reverse(),
        [0, 0],
        [6, 0],
        [52, 53].reverse(), // Velo stable, Velo volatile
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})


it("USDC->WMNT->WETH exactOut (fusionV2, moe)", async function () {

    const amount = parseUnits('0.001', 18)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [weth, wmnt, usdc],
        [FeeAmount.LOW, FeeAmount.LOW],
        [3, 1],
        [51, 50], // butter, Fusion
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("USDC->WMNT->WETH exactOut (cleo, moe)", async function () {

    const amount = parseUnits('0.001', 18)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [wmnt, weth, usdc],
        [FeeAmount.LOW, FeeAmount.LOW],
        [3, 1],
        [51, 3], // moe, cleo
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})


it("USDC->WMNT-WBTC exactOut (moe, moe)", async function () {

    const amount = parseUnits('0.0001', 8)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [wbtc, wmnt, usdc],
        [FeeAmount.LOW, FeeAmount.LOW],
        [3, 1],
        [51, 51], // Velo volatile, fusion
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})


it("WBTC->WMNT->USDC exactOut (moe, moe)", async function () {

    const amount = parseUnits('1', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.WBTC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [wbtc, wmnt, usdc].reverse(),
        [FeeAmount.LOW, FeeAmount.LOW],
        [3, 1],
        [51, 51].reverse(), // Velo volatile, fusion
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})
