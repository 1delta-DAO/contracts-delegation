import { impersonateAccount, mine, setCode } from "@nomicfoundation/hardhat-network-helpers";
import {
    DeltaBrokerProxy,
    DeltaBrokerProxy__factory,
    DeltaFlashAggregator__factory,
    Pool,
    Pool__factory
} from "../types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { network } from "hardhat";
import {
    aaveAddresses,
    aaveBrokerAddresses
} from "../deploy/polygon_addresses";
import { DeltaFlashAggregator, DeltaFlashAggregatorInterface } from "../types/DeltaFlashAggregator";
import { addressesTokens } from "../scripts/aaveAddresses";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { Contract } from "ethers";
const { ethers } = require("hardhat");

const POLYGON_CHAIN_ID = 137;
const trader = '0x5582df1f68731726d0CAF015893ad36Eb153b8D5'
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
    // const newflashAggregator = await new DeltaFlashAggregator__factory(signer).deploy()
    // const traderModule = aaveBrokerAddresses.MarginTraderModule[POLYGON_CHAIN_ID]
    // console.log("get code")
    // const newflashAggregatorCode = await network.provider.send("eth_getCode", [
    //     newflashAggregator.address,
    // ]
    // )
    // console.log("set code")
    // set the code
    // await setCode(traderModule, newflashAggregatorCode)
    await mine(3)
    console.log("fetch flash broker")
    flashConract = await new DeltaFlashAggregator__factory(impersonatedSigner).attach(proxy)

    aavePool = await new Contract(aaveAddresses.v3pool[POLYGON_CHAIN_ID], Pool__factory.createInterface(), impersonatedSigner) as Pool
})


it("Test Close", async function () {

    await impersonateAccount(trader)
    const impersonatedSigner = await ethers.getSigner(trader);

    await multicaller.connect(impersonatedSigner).multicall(close_calldatas)

})

const close_calldatas = [
    '0x2d4c2e9bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000002e7ceb23fd6bc0add59e62ac25578270cff1b9f6190001f400052791bca1f2de4661ed88a30c99a7a9449aa8417403000000000000000000000000000000000000',
    '0xc4a7edaa000000000000000000000000625e7708f30ca75bfd92586e17077590c60eb4cd0000000000000000000000000000000000000000000000000000000017259e56',
    '0xf940e3850000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa841740000000000000000000000005582df1f68731726d0caf015893ad36eb153b8d5'
]