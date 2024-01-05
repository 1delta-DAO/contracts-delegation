import { impersonateAccount, mine, setCode } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import { DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory } from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addressesTokensMantle } from "../scripts/mantle/lendleAddresses";
import { network } from "hardhat";
const { ethers } = require("hardhat");

const MANTLE_CHAIN_ID = 5000;
const admin = ''
let multicaller: DeltaBrokerProxy
let flashAggregatorInterface: DeltaFlashAggregatorMantleInterface
let user: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(user).attach(lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID])
    flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()

    console.log("deploy new aggregator")
    const newflashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).deploy()
    await impersonateAccount(admin)
    const impersonatedSigner = await ethers.getSigner(admin);
    console.log(impersonatedSigner.address)

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


it("Test deposit", async function () {
    const amount = parseUnits('1.0', 18)
    const tokenIn = addressesTokensMantle.WMNT
    const callWrap = flashAggregatorInterface.encodeFunctionData('wrap',)
    const callDeposit = flashAggregatorInterface.encodeFunctionData('deposit' as any, [tokenIn, user.address])
    await multicaller.estimateGas.multicall([callWrap, callDeposit], { value: amount })
})