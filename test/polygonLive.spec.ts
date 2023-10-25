import { impersonateAccount, mine, setCode } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import { DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregator__factory, FlashAggregator__factory, MockERC20__factory } from "../types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { network } from "hardhat";
import { aaveBrokerAddresses } from "../deploy/polygon_addresses";
import { DeltaFlashAggregator, DeltaFlashAggregatorInterface } from "../types/DeltaFlashAggregator";
import { addressesTokens } from "../scripts/aaveAddresses";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount, MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
const { ethers } = require("hardhat");

const POLYGON_CHAIN_ID = 137;
const trader = '0x448CC254819520BF086BCf01245982fAB75c3F66'
const link = '0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39'
const usdc = '0x2791bca1f2de4661ed88a30c99a7a9449aa84174'
const linkPool = '0x0A28C2F5E0E8463E047C203F00F649812aE67E4f'
let multicaller: DeltaBrokerProxy
let flashAggregatorInterface: DeltaFlashAggregatorInterface
let user: SignerWithAddress
let flashConract: DeltaFlashAggregator
let impersonatedSigner: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    const proxy = aaveBrokerAddresses.BrokerProxy[POLYGON_CHAIN_ID]
    multicaller = await new DeltaBrokerProxy__factory(user).attach(proxy)
    flashAggregatorInterface = DeltaFlashAggregator__factory.createInterface()

    console.log("deploy new aggregator")
    const newflashAggregator = await new DeltaFlashAggregator__factory(signer).deploy()
    await impersonateAccount(trader)
    impersonatedSigner = await ethers.getSigner(trader);
    console.log(impersonatedSigner.address)

    const traderModule = aaveBrokerAddresses.MarginTraderModule[POLYGON_CHAIN_ID]
    console.log("get code")
    const newflashAggregatorCode = await network.provider.send("eth_getCode", [
        newflashAggregator.address,
    ]
    )
    console.log("set code")
    // set the code
    await setCode(traderModule, newflashAggregatorCode)
    await mine(2)

    flashConract = await new FlashAggregator__factory(impersonatedSigner).attach(proxy)

})


it("Test open", async function () {
    const amount = parseUnits('10.0', 18)
    const tokenIn = addressesTokens.LINK[POLYGON_CHAIN_ID]
    const tokenOut = addressesTokens.USDC[POLYGON_CHAIN_ID]
    const connecting = addressesTokens.WMATIC[POLYGON_CHAIN_ID]

    const tokenInContract = await new MockERC20__factory(impersonatedSigner).attach(tokenIn)
    const tokenConnectingContract = await new MockERC20__factory(impersonatedSigner).attach(connecting)
    const balIn = await tokenInContract.balanceOf(linkPool)
    const balConnecting = await tokenConnectingContract.balanceOf(linkPool)

    console.log("Exotic balance", balIn.toString(), balConnecting.toString())

    const path = encodeAggregatorPathEthers(
        [tokenIn, connecting, tokenOut],
        [FeeAmount.LOW, FeeAmount.LOW],
        [6, 0], // action
        [0, 0], // pid - V3
        2 // flag - borrow variable
    )

    await flashConract.flashSwapExactIn(amount, MaxUint128, path)
})