import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import {
    ConfigModule__factory,
    DeltaBrokerProxy,
    DeltaBrokerProxy__factory,
    DeltaFlashAggregatorMantle__factory,
    DeltaLendingInterfaceMantle__factory,
    LensModule__factory,
    ManagementModule__factory,
    StableDebtToken__factory,
} from "../types";
import { ONE_DELTA_ADDRESSES } from "../deploy/mantle_addresses";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {  encodeAggregatorPathEthersMargin } from "./1delta/shared/aggregatorPath";
import {  MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
import { ModuleConfigAction, getSelectors } from "./libraries/diamond";
import { addMantleLenderTokens } from "./utils/addTokens";
import { AURELIUS_V_TOKENS } from "../scripts/mantle/addresses/aureliusAddresses";
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
const managementModule = ONE_DELTA_ADDRESSES.ManagementModule[MANTLE_CHAIN_ID]
let multicaller: DeltaBrokerProxy
const flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
const lendingInterfaceInterface = DeltaLendingInterfaceMantle__factory.createInterface()
let user: SignerWithAddress
let trader: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(user).attach(brokerProxy)

    console.log("deploy new aggregator")
    const newFlashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).deploy()
    const newLendingInterface = await new DeltaLendingInterfaceMantle__factory(signer).deploy()
    const newManager = await new ManagementModule__factory(signer).deploy()


    await impersonateAccount(admin)
    const impersonatedSigner = await ethers.getSigner(admin);
    console.log(impersonatedSigner.address)

    const config = await new ConfigModule__factory(impersonatedSigner).attach(brokerProxy)
    const lens = await new LensModule__factory(impersonatedSigner).attach(brokerProxy)

    const selectors = await lens.moduleFunctionSelectors(traderModule)
    const selectorsLending = await lens.moduleFunctionSelectors(lendingModule)
    const selectorsManagement = await lens.moduleFunctionSelectors(managementModule)

    await config.configureModules([
        {
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
            moduleAddress: ethers.constants.AddressZero,
            action: ModuleConfigAction.Remove,
            functionSelectors: selectorsManagement
        },
        {
            moduleAddress: newFlashAggregator.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(newFlashAggregator)
        },
        {
            moduleAddress: newLendingInterface.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(newLendingInterface)
        },
        {
            moduleAddress: newManager.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(newManager)
        },
    ]
    )


    await addMantleLenderTokens(impersonatedSigner, brokerProxy)
})

it("Deposit", async function () {
    const amount = parseUnits('5.0', 18)
    const callWrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const callDeposit = lendingInterfaceInterface.encodeFunctionData('deposit', [wmnt, user.address, 1])

    await multicaller.connect(user).multicall([
        callWrap,
        callDeposit
    ], { value: amount })
})

it("USDT->USDC exactIn (stratum_stable)", async function () {
    const amount = parseUnits('2.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(AURELIUS_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [usdt, usdc],
        [0],
        [6],
        [57], // Stratum Stable
        2,
        1
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    await multicaller.connect(user).multicall([
        callSwap
    ])
})



it("USDT->USDC exactOut (Stratum_stable)", async function () {
    const amount = parseUnits('1.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(AURELIUS_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [usdc, usdt],
        [0],
        [3],
        [57], // Stratum Stable
        2,
        1
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactOut', [amount, MaxUint128, path1])
    await multicaller.connect(user).multicall([
        callSwap
    ])

})

it("USDC->WMNT->WETH exactIn (stratum_volatile, fusionx_v2)", async function () {

    const amount = parseUnits('1.0', 6)

    const borrowToken = await new StableDebtToken__factory(user).attach(AURELIUS_V_TOKENS.USDC)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path1 = encodeAggregatorPathEthersMargin(
        [usdc, wmnt, weth],
        [0, 0],
        [6, 0],
        [56, 51], // stratum Volatile, fusionX
        2,
        1
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amount, 0, path1])
    await multicaller.connect(user).multicall([
        callSwap
    ])
})
