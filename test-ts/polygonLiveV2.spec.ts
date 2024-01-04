import { impersonateAccount, mine, setCode } from "@nomicfoundation/hardhat-network-helpers";
import {  DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregator__factory, MockERC20__factory, Pool, Pool__factory} from "../types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { network } from "hardhat";
import { aaveAddresses, aaveBrokerAddresses } from "../deploy/polygon_addresses";
import { DeltaFlashAggregator, DeltaFlashAggregatorInterface } from "../types/DeltaFlashAggregator";
import { addressesTokens } from "../scripts/aaveAddresses";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { Contract } from "ethers";
const { ethers } = require("hardhat");

const POLYGON_CHAIN_ID = 137;
const trader = '0x448CC254819520BF086BCf01245982fAB75c3F66'
let multicaller: DeltaBrokerProxy
let flashAggregatorInterface: DeltaFlashAggregatorInterface
let user: SignerWithAddress
let flashConract: DeltaFlashAggregator
let impersonatedSigner: SignerWithAddress
let aavePool: Pool


const proxy = aaveBrokerAddresses.BrokerProxy[POLYGON_CHAIN_ID]
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
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
    console.log("fetch flash broker")
    flashConract = await new DeltaFlashAggregator__factory(impersonatedSigner).attach(proxy)

    aavePool = await new Contract(aaveAddresses.v3pool[POLYGON_CHAIN_ID], Pool__factory.createInterface(), impersonatedSigner) as Pool
})


it("Test WMATIC->AIMX on QUICKSWAP_V2", async function () {
    //"blockNumber": "50534168",
    const amount = '4000000000000000000'
    const tokenIn = addressesTokens.WMATIC[POLYGON_CHAIN_ID]
    const token1 = addressesTokens.USDC[POLYGON_CHAIN_ID]
    const token2 = '0xd838290e877e0188a4a44700463419ed96c16107' //nct
    const tokenOut = '0x4e78011ce80ee02d2c3e649fb657e45898257815' // KLIMA


    const path = encodeAggregatorPathEthers(
        [tokenIn, token1, token2, tokenOut],
        [0, 0, 0], // fees
        [0, 0, 0], // ei
        [50, 51, 51], // quick V2, sushi v2, sushi V2
        99 // flag - spot
    )

    const callDepo = flashAggregatorInterface.encodeFunctionData('wrap')
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amount, 0, path])
    const callSweep = flashAggregatorInterface.encodeFunctionData('sweep', [tokenOut])

    await multicaller.multicall([callDepo, callSwap, callSweep], { value: amount })

    const outToken = await new MockERC20__factory(user).attach(tokenOut)
    const balance = await outToken.balanceOf(user.address)
    console.log("amount received:", balance.toString())
})