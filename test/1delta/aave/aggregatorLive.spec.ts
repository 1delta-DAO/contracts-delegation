import { expect } from "chai";
import { constants } from "ethers";
import { findBalanceSlot, getSlot } from "../shared/forkUtils";
import { aaveAddresses, generalAddresses, uniswapAddresses } from "../../../deploy/polygon_addresses";
import { addressesTokens } from "../../../scripts/aaveAddresses";
import { ERC20, FlashAggregator__factory, Pool, Pool__factory, VariableDebtToken } from "../../../types";
import { createBrokerV2, initializeBroker } from '../../../deploy/1delta/00_helper'
import { addBalancer } from "../shared/aaveBrokerFixture";
import { expandToDecimals } from "../shared/misc";
import axios from "axios";
import { InterestRateMode } from "../shared/aaveFixture";
import { encodeAggregatorPathEthers } from "../shared/aggregatorPath";
const { ethers } = require("hardhat");

const POLYGON_CHAIN_ID = 137;

const aavePool = aaveAddresses.v3pool[POLYGON_CHAIN_ID]
const balancerV2Vault = '0xBA12222222228d8Ba445958a75a0704d566BF2C8'
const uniswapFactoryAddress = uniswapAddresses.factory[POLYGON_CHAIN_ID]
const usdcAddress = addressesTokens.USDC[POLYGON_CHAIN_ID]
const wmaticAddress = generalAddresses.WETH[POLYGON_CHAIN_ID]
const wethAddress = addressesTokens.WETH[POLYGON_CHAIN_ID]

const vWETHAddress = '0x0c84331e39d6658Cd6e6b9ba04736cC4c4734351'
const paraswapRouter = '0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57'
const oneInchRouter = '0x1111111254eeb25477b68fb85ed929f73a960582'

const brokerProxy = '0x18828A9E0b5274Eb8EB152d35B17fB8AF1a29325'

async function fetchData(url: string) {
    try {
        const response = await axios.get(url);
        return response.data
    } catch (error) {
        console.log(error);
    }
}

const poolFee = 500

it("Mint USDC", async function () {
    const [signer] = await ethers.getSigners();
    console.log("usdcAddress", usdcAddress)
    let usdc = await ethers.getContractAt("UChildAdministrableERC20", usdcAddress);
    const signerAddress = await signer.getAddress();
    console.log("signer", signer.address)

    // automatically find mapping slot
    const mappingSlot = await findBalanceSlot(usdc)
    console.log("Found USDC.balanceOf slot: ", mappingSlot)

    // calculate balanceOf[signerAddress] slot
    const signerBalanceSlot = getSlot(signerAddress, mappingSlot)

    const depositBalance = expandToDecimals(10000, 6)
    // console.log("SLot", signerBalanceSlot)
    // set it to the value
    const value: any = Number(depositBalance.toString())
    await ethers.provider.send(
        "hardhat_setStorageAt",
        [
            usdc.address,
            signerBalanceSlot,
            ethers.utils.hexlify(ethers.utils.zeroPad(value, 32))
        ]
    )

    // check that the user balance is equal to the expected value
    expect(await usdc.balanceOf(signerAddress)).to.be.eq(value)

    const usdcContract = usdc as ERC20

    const aavePoolContract = await ethers.getContractAt("Pool", aavePool) as Pool

    console.log("Deploy  broker")
    // const broker = await new FlashAggregator__factory(signer).attach(brokerProxy)
    const broker = await createBrokerV2(signer, uniswapFactoryAddress, aavePool)
    await initializeBroker(signer, broker, aavePool)


    await usdcContract.connect(signer).approve(aavePoolContract.address, constants.MaxUint256)

    await aavePoolContract.connect(signer).supply(usdcContract.address, depositBalance, signerAddress, 0)

    const vWETHContract = await ethers.getContractAt("VariableDebtToken", vWETHAddress) as VariableDebtToken

    await vWETHContract.connect(signer).approveDelegation(broker.brokerProxy.address, constants.MaxUint256)
    await broker.manager.connect(signer).approveLendingPool([usdcAddress])
    const swapAmount = expandToDecimals(2, 18)

    const fromToken = wethAddress
    const toTokenAddress = usdcAddress

    const path = encodeAggregatorPathEthers(
        [fromToken, toTokenAddress],
        [poolFee],
        [6], // action
        [0], // pid - V3
        2 // flag - borrow variable
    )
    console.log("path", path)

    await broker.broker.flashSwapExactIn(
        swapAmount,
        0,
        path
    )

})
