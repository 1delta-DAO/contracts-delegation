import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { formatEther, parseUnits } from "ethers/lib/utils";
import { AToken__factory, ConfigModule__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory, DeltaLendingInterfaceMantle, DeltaLendingInterfaceMantle__factory, ERC20Mock__factory, LensModule__factory, StableDebtToken__factory, } from "../types";
import { ONE_DELTA_ADDRESSES } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { LENDLE_A_TOKENS, LENDLE_V_TOKENS, addressesTokensMantle } from "../scripts/mantle/addresses/lendleAddresses";
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
const moe = "0x4515A45337F461A11Ff0FE8aBF3c606AE5dC00c9"

const brokerProxy = ONE_DELTA_ADDRESSES.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = ONE_DELTA_ADDRESSES.MarginTraderModule[MANTLE_CHAIN_ID]
let multicaller: DeltaBrokerProxy
let flashAggregatorInterface: DeltaFlashAggregatorMantleInterface
let lendingInterfaceInterface: DeltaLendingInterfaceMantleInterface
let signer: SignerWithAddress
let trader: SignerWithAddress
before(async function () {
    const [_signer] = await ethers.getSigners();
    signer = _signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(signer).attach(brokerProxy)
    flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
    lendingInterfaceInterface = DeltaLendingInterfaceMantle__factory.createInterface()


})

it("Executes single TX upgrade", async function () {
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
    await config.configureModules([
        {
            moduleAddress: ethers.constants.AddressZero,
            action: ModuleConfigAction.Remove,
            functionSelectors: selectors
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
        }
    ])
})


it("Deposit and multicall", async function () {
    const amount = parseUnits('5000.0', 18)
    const callWrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const callUnwrap = lendingInterfaceInterface.encodeFunctionData('unwrap',)
    const callDeposit = lendingInterfaceInterface.encodeFunctionData('deposit' as any, [usdc, signer.address])

    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, wmnt],
        [FeeAmount.LOW],
        [1],
        [0],
        99
    )
    const amountOut1 = "800000000"
    const swap1 = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amountOut1, MaxUint128, path1])


    const amountIn = parseUnits('20.0', 6)

    const borrowToken = await new StableDebtToken__factory(signer).attach(LENDLE_V_TOKENS.USDT)
    await borrowToken.approveDelegation(multicaller.address, MaxUint128)
    // v3 single
    const path2 = encodeAggregatorPathEthers(
        [usdt, usdc],
        [0],
        [6],
        [53], // Velo Stable
        2
    )
    const callSwapMargin = flashAggregatorInterface.encodeFunctionData('flashSwapExactIn', [amountIn, 0, path2])

    await multicaller.connect(signer).multicall([
        callWrap,
        swap1,
        callDeposit,
        callSwapMargin,
        callUnwrap
    ], { value: amount })
})

it("spot exotic exactIn", async function () {
    const amount = parseUnits('5000.0', 18)
    const callWrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const callUnwrap = lendingInterfaceInterface.encodeFunctionData('unwrap',)

    const amountIn = parseUnits('100', 18)

    console.log("swap", formatEther(amountIn))

    // v3 single
    const pathSpot = encodeAggregatorPathEthers(
        [wmnt, usdt, moe],
        [500, 0],
        [0, 0],
        [1, 51], // agni, moe
        99
    )
    const swap2 = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amountIn, 0, pathSpot])

    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [moe])

    await multicaller.connect(signer).multicall([
        callWrap,
        swap2,
        sweep,
        callUnwrap
    ],
        { value: amount }
    )
    const moeToken = new ERC20Mock__factory(signer).attach(moe)
    const received = await moeToken.balanceOf(signer.address)
    console.log(formatEther(received))
})


it("spot exotic exactOut", async function () {
    const moeToken = new ERC20Mock__factory(signer).attach(moe)
    const balance = await moeToken.balanceOf(signer.address)
    console.log(formatEther(balance))

    const amountOut = parseUnits('80', 18)

    const wmntToken = new ERC20Mock__factory(signer).attach(wmnt)
    console.log("swap", formatEther(amountOut))
    const before = await wmntToken.balanceOf(signer.address)
    // v3 single
    const pathSpot = encodeAggregatorPathEthers(
        [wmnt, usdt, moe],
        [500, 0],
        [1, 1],
        [1, 51], // agni, moe
        99
    )
    const swap2 = flashAggregatorInterface.encodeFunctionData('swapExactOutSpot', [amountOut, MaxUint128, pathSpot])

    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [wmnt])

    await moeToken.approve(multicaller.address, MaxUint128)

    await multicaller.connect(signer).multicall([
        swap2,
        sweep
    ]
    )
    const balanceAfer = await moeToken.balanceOf(signer.address)
    const received = await wmntToken.balanceOf(signer.address)
    console.log("received", formatEther(received.sub(before)))
    console.log("paid", formatEther(balance.sub(balanceAfer)))
})
