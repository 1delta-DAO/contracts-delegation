import { expect } from "chai";
import {  constants } from "ethers";
import { findBalanceSlot, getSlot } from "../shared/forkUtils";
import { aaveAddresses, generalAddresses, uniswapAddresses } from "../../../deploy/polygon_addresses";
import { addressesAaveATokens, addressesTokens } from "../../../scripts/aaveAddresses";
import { AToken, ERC20, Pool, VariableDebtToken } from "../../../types";
import { expandToDecimals } from "../shared/misc";
import axios from "axios";
import { InterestRateMode } from "../shared/aaveFixture";
import { initializeFlashBroker } from "../../../deploy/1delta/00_initializeFlashBroker";
import { createFlashBroker } from "../../../deploy/1delta/00_helperFlash";
const { ethers } = require("hardhat");

const POLYGON_CHAIN_ID = 137;

const aavePool = aaveAddresses.v3pool[POLYGON_CHAIN_ID]
const balancerV2Vault = '0xBA12222222228d8Ba445958a75a0704d566BF2C8'
const uniswapFactoryAddress = uniswapAddresses.factory[POLYGON_CHAIN_ID]
const usdcAddress = addressesTokens.USDC[POLYGON_CHAIN_ID]
const wmaticAddress = generalAddresses.WETH[POLYGON_CHAIN_ID]
const wethAddress = addressesTokens.WETH[POLYGON_CHAIN_ID]
const aWETHaddress = addressesAaveATokens.WETH[POLYGON_CHAIN_ID]
const vWETHAddress = '0x0c84331e39d6658Cd6e6b9ba04736cC4c4734351'
const paraswapRouter = '0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57'
const oneInchRouter = '0x1111111254eeb25477b68fb85ed929f73a960582'
async function fetchData(url: string) {
    try {
        const response = await axios.get(url);
        return response.data
    } catch (error) {
        console.log(error);
    }
}

it("Mint USDC", async function () {
    const [signer] = await ethers.getSigners();
    const chainId = await signer.getChainId()
    console.log("usdcAddress", usdcAddress)
    let usdc = await ethers.getContractAt("UChildAdministrableERC20", usdcAddress);
    const signerAddress = await signer.getAddress();
    console.log("signer", signer.address, "chainID", chainId)

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
    const broker = await createFlashBroker(signer, aavePool, balancerV2Vault)
    await initializeFlashBroker(chainId, signer, broker.proxy.address, aavePool)

    const balancerModule =  broker.flashBrokerAave //await addAaveFlashLoans(signer, broker as any, oneInchRouter, aavePool)
    await broker.manager.setValidTarget(oneInchRouter, true)
    await usdcContract.connect(signer).approve(aavePoolContract.address, constants.MaxUint256)

    await aavePoolContract.connect(signer).supply(usdcContract.address, depositBalance, signerAddress, 0)

    const vWETHContract = await ethers.getContractAt("VariableDebtToken", vWETHAddress) as VariableDebtToken

    await vWETHContract.connect(signer).approveDelegation(balancerModule.address, constants.MaxUint256)
    await broker.manager.connect(signer).approveAddress([usdcAddress, wethAddress], aavePoolContract.address)
    const swapAmount = expandToDecimals(2, 18)

    const fromToken = wethAddress
    const toTokenAddress = usdcAddress
    const slippage = 45
    const nodeAddress = balancerModule.address
    console.log("NodeAddress", nodeAddress)


    const url = `https://api.1inch.io/v5.0/137/swap?fromTokenAddress=${fromToken
        }&toTokenAddress=${toTokenAddress
        }&amount=${swapAmount.toString()
        }&fromAddress=${nodeAddress
        }&slippage=${slippage
        }&destReceiver=${nodeAddress
        }&referrerAddress=${nodeAddress
        }&disableEstimate=true&compatibilityMode=true&burnChi=false&allowPartialFill=false&complexityLevel=0`
    console.log("URL", url)

    const API_DATA: any = await fetchData(url)

    const params = {
        baseAsset: toTokenAddress, // the asset to interact with
        target: oneInchRouter,
        swapType: 0, // exact in
        marginTradeType: 0, // margin open
        interestRateModeIn: InterestRateMode.VARIABLE, // the borrow mode
        interestRateModeOut: 0, // unused
        referenceAmount: 0,
        withdrawMax: false
    }
    console.log("Executing trade: open margin")
    await balancerModule.executeOnAave(
        wethAddress,
        swapAmount,
        params,
        API_DATA.tx.data
    )


    const aWETHContract = await ethers.getContractAt("AToken", aWETHaddress) as AToken

    await aWETHContract.connect(signer).approve(balancerModule.address, constants.MaxUint256)

    // const paramsCs = {
    //     baseAsset: toTokenAddress, // the asset to interact with
    //     target: oneInchRouter,
    //     swapType: 0, // exact in
    //     marginTradeType: 0, // margin open
    //     interestRateModeIn: InterestRateMode.VARIABLE, // the borrow mode
    //     interestRateModeOut: 0, // unused
    //     referenceAmount: 0
    // }
    // console.log("Executing trade: open margin")
    // await balancerModule.executeOnAave(
    //     wethAddress,
    //     swapAmount,
    //     params,
    //     API_DATA.tx.data
    // )

})
