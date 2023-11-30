import { impersonateAccount, mine, setCode } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import { BorrowLogic__factory, BridgeLogic__factory, ConfiguratorLogic__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregator__factory, EModeLogic__factory, FlashAggregator__factory, FlashLoanLogic__factory, LiquidationLogic__factory, MockERC20__factory, Pool, PoolLogic__factory, Pool__factory, SupplyLogic__factory, VariableDebtToken__factory } from "../types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { network } from "hardhat";
import { aaveAddresses, aaveBrokerAddresses } from "../deploy/polygon_addresses";
import { DeltaFlashAggregator, DeltaFlashAggregatorInterface } from "../types/DeltaFlashAggregator";
import { PoolInterface } from "../types/Pool";
import { addressesAaveVTokens, addressesTokens } from "../scripts/aaveAddresses";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount, MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
import { InterestRateMode } from "./1delta/shared/aaveFixture";
import { Contract } from "ethers";
const { ethers } = require("hardhat");

const POLYGON_CHAIN_ID = 137;
const aaveAddressProvider = '0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb'
const aavePoolImplementation = '0xb77fc84a549ecc0b410d6fa15159C2df207545a3'
const trader = '0x448CC254819520BF086BCf01245982fAB75c3F66'
const link = '0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39'
const usdc = '0x2791bca1f2de4661ed88a30c99a7a9449aa84174'
const linkPool = '0x0A28C2F5E0E8463E047C203F00F649812aE67E4f'
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