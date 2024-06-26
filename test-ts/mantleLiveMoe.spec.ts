import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import { ConfigModule__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory, DeltaLendingInterfaceMantle__factory, LensModule__factory, StableDebtToken__factory, } from "../types";
import { ONE_DELTA_ADDRESSES } from "../deploy/mantle_addresses";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { LENDLE_V_TOKENS, addressesTokensMantle } from "../scripts/mantle/addresses/lendleAddresses";
import { encodeAggregatorPathEthersMargin } from "./1delta/shared/aggregatorPath";
import { FeeAmount, MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
import { ModuleConfigAction, getSelectors } from "./libraries/diamond";
const { ethers } = require("hardhat");

// block: 20240225
const MANTLE_CHAIN_ID = 5000;
const admin = '0x999999833d965c275A2C102a4Ebf222ca938546f'

const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"

const brokerProxy = ONE_DELTA_ADDRESSES.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = ONE_DELTA_ADDRESSES.MarginTraderModule[MANTLE_CHAIN_ID]
const lendingModule = ONE_DELTA_ADDRESSES.LendingInterface[MANTLE_CHAIN_ID]
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

it("Opens exact in", async function () {
    const amount = parseUnits('2.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [usdt, usdc],
        [0],
        [6],
        [51], // Moe
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])

})

it("Closes exact in", async function () {
    const amount = parseUnits('1.0', 6)

    const borrowToken = await new AToken__factory(user).attach(addressesLendleATokens.USDC)
    await borrowToken.approve(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, usdt],
        [0],
        [8],
        [51], // Moe
        5
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Closes exact Out", async function () {
    const amount = parseUnits('0.7', 6)

    const borrowToken = await new AToken__factory(user).attach(addressesLendleATokens.USDC)
    await borrowToken.approve(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdt, usdc],
        [0],
        [5],
        [51], // Moe
        5
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Opens exact out", async function () {
    const amount = parseUnits('1.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [usdc, usdt],
        [FeeAmount.MEDIUM],
        [3],
        [51], // Moe
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Opens exact in multi", async function () {

    const amount = parseUnits('1.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [usdc, weth, wmnt],
        [0, FeeAmount.LOW],
        [6, 0],
        [51, 51], // Moe, Moe
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Opens exact out multi", async function () {

    const amount = parseUnits('1.0', 18)

    const borrowToken = await new StableDebtToken__factory(user).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [wmnt, weth, usdc],
        [FeeAmount.LOW, FeeAmount.LOW],
        [3, 1],
        [51, 51], // moe, moe
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Closes exact out multi", async function () {

//     const collateralToken = await new AToken__factory(user).attach(addressesLendleATokens.WMNT)
//     const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDT)

//     const balDebt = await borrowToken.balanceOf(user.address)
//     const balCollateral = await collateralToken.balanceOf(user.address)

//     console.log("Bal", balCollateral.toString(), balDebt.toString())
//     // aprove withdrawal
//     await collateralToken.approve(multicaller.address, MaxUint128)

//     // v3 single
//     const path1 = encodeAggregatorPathEthersMargin(
//         [usdt, weth, wmnt],
//         [FeeAmount.LOW, FeeAmount.MEDIUM],
//         [5, 1],
//         [100, 100],
//         3
//     )
//     const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapAllOut', [MaxUint128, path1])
//     console.log("attempt swap")
//     await multicaller.connect(user).multicall([
//         callSwap
//     ])

//     const bal = await borrowToken.balanceOf(user.address)
//     console.log(bal.toString())

// })


// it("Swaps collatera all in", async function () {

//     const collateralToken = await new AToken__factory(user).attach(addressesLendleATokens.WMNT)

//     const balCollateral = await collateralToken.balanceOf(user.address)

//     console.log("Bal", balCollateral.toString())
//     // aprove withdrawal
//     await collateralToken.approve(multicaller.address, MaxUint128)

//     // v3 single
//     const path1 = encodeAggregatorPathEthersMargin(
//         [wmnt, weth, usdt],
//         [FeeAmount.MEDIUM, FeeAmount.LOW],
//         [6, 0],
//         [100, 100],
//         3
//         // [wmnt, weth, usdt],
//         // [FeeAmount.LOW, FeeAmount.LOW],
//         // [6, 0],
//         // [0, 100],
//         // 3
//     )
//     const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapAllIn', [0, path1])
//     console.log("attempt swap")
//     await multicaller.connect(user).multicall([
//         callSwap
//     ])

//     const bal = await collateralToken.balanceOf(user.address)
//     console.log(bal.toString())

// })



// it("Opens exact in multi (WMNT-USDT)", async function () {
//     const amount = parseUnits('5.0', 18)
//     const tokenIn = addressesTokensMantle.WMNT

//     const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.WMNT)
//     await borrowToken.approveDelegation(multicaller.address, MaxUint128)
//     // v3 single
//     const path1 = encodeAggregatorPathEthersMargin(
//         [wmnt, weth, usdt],
//         [FeeAmount.MEDIUM, FeeAmount.LOW],
//         [6, 0],
//         [100, 0],
//         2
//     )
//     const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
//     console.log("attempt swap")
//     await multicaller.connect(user).multicall([
//         callSwap
//     ])
// })


// it("Closes all out multi (USDT-WMNT)", async function () {

//     const collateralToken = await new AToken__factory(user).attach(addressesLendleATokens.USDT)
//     const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.WMNT)

//     const balDebt = await borrowToken.balanceOf(user.address)
//     const balCollateral = await collateralToken.balanceOf(user.address)

//     console.log("Bal", balCollateral.toString(), balDebt.toString())
//     // aprove withdrawal
//     await collateralToken.approve(multicaller.address, MaxUint128)

//     // v3 single
//     const path1 = encodeAggregatorPathEthersMargin(
//         [wmnt, weth, usdt],
//         [FeeAmount.MEDIUM, FeeAmount.LOW],
//         [5, 1],
//         [100, 100],
//         3
//     )
//     const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapAllOut', [MaxUint128, path1])
//     console.log("attempt swap")
//     await multicaller.connect(user).multicall([
//         callSwap
//     ])

//     const bal = await borrowToken.balanceOf(user.address)
//     console.log("left:", bal.toString())
//     const wmntToken = await new AToken__factory(user).attach(wmnt)

//     const dust = await wmntToken.balanceOf(multicaller.address)
//     console.log("dust:", dust.toString())
// })

    const borrowToken = await new AToken__factory(user).attach(addressesLendleATokens.WMNT)
    await borrowToken.approve(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, weth, wmnt],
        [FeeAmount.LOW, FeeAmount.LOW],
        [5, 1],
        [51, 51], // moe, moe
        5
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})
