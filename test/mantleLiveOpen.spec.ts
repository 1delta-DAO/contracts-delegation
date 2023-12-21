import { impersonateAccount, mine, setCode } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import { ConfigModule__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle, DeltaFlashAggregatorMantle__factory, DeltaFlashAggregator__factory, OneDeltaQuoterMantle, OneDeltaQuoterMantle__factory, } from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addressesTokensMantle } from "../scripts/mantle/lendleAddresses";
import { network } from "hardhat";
const { ethers } = require("hardhat");

const MANTLE_CHAIN_ID = 5000;
const trader0 = '0xC54Fb551858060d193ACE07998F4D3313FBE35E3'

const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"

let multicaller: DeltaBrokerProxy
let flashAggregator: DeltaFlashAggregatorMantle
let flashAggregatorInterface: DeltaFlashAggregatorMantleInterface
let user: SignerWithAddress
let trader: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(user).attach(lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID])
    flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
    flashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).attach(multicaller.address)
    console.log("deploy new aggregator")
    const newflashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).deploy()

    const traderModule = lendleBrokerAddresses.MarginTraderModule[MANTLE_CHAIN_ID]
    console.log("get code")
    const newflashAggregatorCode = await network.provider.send("eth_getCode", [
        newflashAggregator.address,
    ]
    )
    console.log("set code")
    // set the code
    await setCode(traderModule, newflashAggregatorCode)
    await mine(2)

})


it("Test open", async function () {
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);

    const amountIn = '823000000'
    const amountOutMinimum = '822151801'
    const path = '0x201eba5cc46d216ce6dc03f6a759e8e766e956ae000064010609bc4e0d864854c6afb6eb9a9cdf58ac190d0df902'


    await flashAggregator.connect(impersonatedSigner).flashSwapExactIn(
        amountIn,
        amountOutMinimum,
        path
    )

})

