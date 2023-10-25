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

const deployAndReplacePool = async (_deployer: SignerWithAddress, addressProvider: string) => {
    // deploy logics
    const libLiquidationLogic = await new LiquidationLogic__factory(_deployer).deploy()
    const libSupplyLogic = await new SupplyLogic__factory(_deployer).deploy()
    const libEModeLogic = await new EModeLogic__factory(_deployer).deploy()
    const libBorrowLogic = await new BorrowLogic__factory(_deployer).deploy()
    const libFlashLoanLogic = await new FlashLoanLogic__factory(
        { ["contracts/external-protocols/aave-v3-core/protocol/libraries/logic/BorrowLogic.sol:BorrowLogic"]: libBorrowLogic.address }
        , _deployer
    ).deploy()
    const libPoolLogic = await new PoolLogic__factory(_deployer).deploy()
    const libBridgeLogic = await new BridgeLogic__factory(_deployer).deploy()

    const inp = {
        ["contracts/external-protocols/aave-v3-core/protocol/libraries/logic/LiquidationLogic.sol:LiquidationLogic"]: libLiquidationLogic.address,
        ["contracts/external-protocols/aave-v3-core/protocol/libraries/logic/SupplyLogic.sol:SupplyLogic"]: libSupplyLogic.address,
        ["contracts/external-protocols/aave-v3-core/protocol/libraries/logic/EModeLogic.sol:EModeLogic"]: libEModeLogic.address,
        ["contracts/external-protocols/aave-v3-core/protocol/libraries/logic/BorrowLogic.sol:BorrowLogic"]: libBorrowLogic.address,
        ["contracts/external-protocols/aave-v3-core/protocol/libraries/logic/FlashLoanLogic.sol:FlashLoanLogic"]: libFlashLoanLogic.address,
        ["contracts/external-protocols/aave-v3-core/protocol/libraries/logic/PoolLogic.sol:PoolLogic"]: libPoolLogic.address,
        ["contracts/external-protocols/aave-v3-core/protocol/libraries/logic/BridgeLogic.sol:BridgeLogic"]: libBridgeLogic.address
    }
    const libConfigLogic = await new ConfiguratorLogic__factory(_deployer).deploy()

    // deploy pool
    const pool = await new Pool__factory(inp, _deployer).deploy(addressProvider)
    console.log("get code")
    const newPoolCode = await network.provider.send("eth_getCode", [
        pool.address,
    ]
    )
    await setCode(aavePoolImplementation, newPoolCode)
}

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

    console.log("replacePool")
    await deployAndReplacePool(signer, aaveAddressProvider)
    console.log("fetch aave pool@", aaveAddresses.v3pool[POLYGON_CHAIN_ID])
    aavePool = await new Contract(aaveAddresses.v3pool[POLYGON_CHAIN_ID], Pool__factory.createInterface(), impersonatedSigner) as Pool
})


it("Test open", async function () {
    const amount = parseUnits('10.0', 18)
    const tokenIn = addressesTokens.LINK[POLYGON_CHAIN_ID]
    const tokenOut = addressesTokens.USDC[POLYGON_CHAIN_ID]
    const connecting = addressesTokens.WMATIC[POLYGON_CHAIN_ID]

    // const amountRaw = parseUnits('1.0', 18)
    // await aavePool.connect(impersonatedSigner).borrow(tokenIn, amountRaw, InterestRateMode.VARIABLE, 0, impersonatedSigner.address)
    const debtToken = await new VariableDebtToken__factory(impersonatedSigner).attach(addressesAaveVTokens.LINK[POLYGON_CHAIN_ID])
    await debtToken.approveDelegation(proxy, amount)
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

    await flashConract.flashSwapExactIn(amount, 0, path)
})