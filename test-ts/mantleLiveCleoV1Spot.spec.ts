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

const cleo = '0xC1E0C8C30F251A07a894609616580ad2CEb547F2'
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

it("WMNT->CLEO exactIn (cleo_v1_vola)", async function () {
    const amount = parseUnits('10', 18)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [cleo])
    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)
    const tokencleo = await new ERC20Mock__factory(user).attach(cleo)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, cleo],
        [0],
        [0],
        [54], // cleo v
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


it("WMNT->CLEO exactOut (cleo_v1_vola)", async function () {
    const amountIn = parseUnits('100', 18)
    const amount = parseUnits('0.041933248267840282', 18)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [cleo])
    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const sweepWmnt = lendingInterfaceInterface.encodeFunctionData('sweep', [wmnt])
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)

    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, cleo].reverse(),
        [0].reverse(),
        [1],
        [54].reverse(), // celo, velo v
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amount, MaxUint128, path1])
    console.log("attempt swap")

    const tokenCleo = await new ERC20Mock__factory(user).attach(cleo)
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

it("WMNT->USDC->GRAI exactIn (velo_stable)", async function () {
    const amount = parseUnits('1.0', 18)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [grai])
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)
    const tokenGrai = await new ERC20Mock__factory(user).attach(grai)

    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, usdc, grai],
        [500, 0],
        [0, 0],
        [1, 55], // agni, cleo s
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amount, 0, path1])
    console.log("attempt swap")

    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const unwrap = lendingInterfaceInterface.encodeFunctionData('unwrap',)
    const balPre = await tokenGrai.balanceOf(trader0)

    await multicaller.connect(impersonatedSigner).multicall([
        wrap,
        callSwap,
        sweep,
        unwrap
    ],
        { value: amount }
    )


    const balAfter = await tokenGrai.balanceOf(trader0)
    console.log("receive", formatEther(balAfter.sub(balPre)))
    console.log("paid", formatEther(amount))
})


it("WMNT->USDC->GRAI exactOut (velo_stable)", async function () {
    const amountOut = parseUnits('0.658144717465350829', 18)
    const amountIn = parseUnits('2.0', 18)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [grai])
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)

    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, usdc, grai].reverse(),
        [500, 0].reverse(),
        [1, 1],
        [1, 55].reverse(), // agni, cleo s
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amountOut, MaxUint128, path1])
    console.log("attempt swap")


    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const sweepWmnt = lendingInterfaceInterface.encodeFunctionData('sweep', [wmnt])

    const tokenGrai = await new ERC20Mock__factory(user).attach(grai)
    const tokenWmnt = await new ERC20Mock__factory(user).attach(wmnt)
    const balPreWmnt = await tokenWmnt.balanceOf(trader0)
    const balPre = await tokenGrai.balanceOf(trader0)
    await multicaller.connect(impersonatedSigner).multicall([
        wrap,
        callSwap,
        sweep,
        sweepWmnt
    ],
        { value: amountIn }
    )
    const balAfterWmnt = await tokenWmnt.balanceOf(trader0)

    const balAfter = await tokenGrai.balanceOf(trader0)
    console.log("receive", formatEther(balAfter.sub(balPre)))
    console.log("paid", formatEther(amountIn.sub(balAfterWmnt.sub(balPreWmnt))))
})
