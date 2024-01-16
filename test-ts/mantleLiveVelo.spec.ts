import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import { AToken__factory, ConfigModule__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory, DeltaLendingInterfaceMantle, DeltaLendingInterfaceMantle__factory, LensModule__factory, StableDebtToken__factory, } from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addressesLendleATokens, addressesLendleVTokens, addressesTokensMantle } from "../scripts/mantle/lendleAddresses";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
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

const brokerProxy = lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = lendleBrokerAddresses.MarginTraderModule[MANTLE_CHAIN_ID]
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

    await config.configureModules([{
        moduleAddress: newLendingInterface.address,
        action: ModuleConfigAction.Add,
        functionSelectors: getSelectors(newLendingInterface)
    }])


})

it("Deposit", async function () {
    const amount = parseUnits('5000.0', 18)
    const callWrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const callDeposit = lendingInterfaceInterface.encodeFunctionData('deposit' as any, [wmnt, user.address])

    await multicaller.connect(user).multicall([
        callWrap,
        callDeposit
    ], { value: amount })
})

it("Opens exact in stable", async function () {
    const amount = parseUnits('2.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
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



it("Opens exact out stable", async function () {
    const amount = parseUnits('1.0', 6)
    const tokenIn = addressesTokensMantle.WMNT

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
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

it("Opens exact in multi", async function () {

    const amount = parseUnits('1.0', 6)
    const tokenIn = addressesTokensMantle.WMNT

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, wmnt, weth],
        [0, FeeAmount.LOW],
        [6, 0],
        [52, 0], // Velo Volatile, fusionX
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})


it("Opens exact out multi", async function () {

    const amount = parseUnits('0.0001', 18)

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
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

it("Opens exact out multi Stable & Variable", async function () {

    const amount = parseUnits('0.0001', 8)

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wbtc, usdc, usdt],
        [FeeAmount.LOW, FeeAmount.LOW],
        [3, 1],
        [52, 53], // butter, Velo volatile
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

it("Opens exact in multi Stable & Variable", async function () {

    const amount = parseUnits('10', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.WBTC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wbtc, usdc, usdt].reverse(),
        [0, 0],
        [6, 0],
        [52, 53].reverse(), // butter, Velo volatile
        2
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    console.log("attempt swap")
    await multicaller.connect(user).multicall([
        callSwap
    ])
})

// it("Closes all out multi", async function () {

//     const collateralToken = await new AToken__factory(user).attach(addressesLendleATokens.WMNT)
//     const borrowToken = await new StableDebtToken__factory(user).attach(addressesLendleVTokens.USDT)

//     const balDebt = await borrowToken.balanceOf(user.address)
//     const balCollateral = await collateralToken.balanceOf(user.address)

//     console.log("Bal", balCollateral.toString(), balDebt.toString())
//     // aprove withdrawal
//     await collateralToken.approve(multicaller.address, MaxUint128)

//     // v3 single
//     const path1 = encodeAggregatorPathEthers(
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
//     const path1 = encodeAggregatorPathEthers(
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
//     const path1 = encodeAggregatorPathEthers(
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
//     const path1 = encodeAggregatorPathEthers(
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

