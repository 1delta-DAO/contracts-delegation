import { expect } from "chai";
import { constants } from "ethers";
import { findBalanceSlot, getSlot } from "../shared/forkUtils";
import { aaveAddresses, generalAddresses, uniswapAddresses } from "../../../deploy/00_addresses";
import { addressesTokens } from "../../../scripts/aaveAddresses";
import { ERC20, Pool, VariableDebtToken } from "../../../types";
import { expandToDecimals } from "../shared/misc";
import axios from "axios";
import { InterestRateMode } from "../shared/aaveFixture";
import { createFlashBroker } from "../../../deploy/1delta/00_helperFlash";
import { approveSpending, initializeFlashBroker } from "../../../deploy/1delta/00_initializeFlashBroker";
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
const paraswapTransferProxy = '0x216b4b4ba9f3e719726886d34a177484278bfcae'
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
    const broker = await createFlashBroker(signer, aavePool, balancerV2Vault, {})
    await initializeFlashBroker(POLYGON_CHAIN_ID, signer, broker.proxy.address, aavePool, true, {})
    await approveSpending(POLYGON_CHAIN_ID, signer, broker.proxy.address)
    const balancerModule = broker.flashBrokerBalancer
    await broker.manager.setValidTarget(oneInchRouter, true)
    await usdcContract.connect(signer).approve(aavePoolContract.address, constants.MaxUint256)

    await aavePoolContract.connect(signer).supply(usdcContract.address, depositBalance, signerAddress, 0)

    const vWETHContract = await ethers.getContractAt("VariableDebtToken", vWETHAddress) as VariableDebtToken

    await vWETHContract.connect(signer).approveDelegation(balancerModule.address, constants.MaxUint256)
    await broker.manager.connect(signer).approveAAVEPool([usdcAddress])
    const swapAmount = expandToDecimals(10000, 6)
    const amountToBorrowMax = expandToDecimals(20, 18)
    const fromToken = wethAddress
    const fromTokenDecimals = 18
    const toTokenAddress = usdcAddress
    const toTokenDecimals = 6
    const slippage = 45
    const nodeAddress = balancerModule.address
    console.log("NodeAddress", nodeAddress)

    const side: string = 'BUY'
    const url = `https://apiv5.paraswap.io/prices?srcToken=${fromToken
        }&srcDecimals=${fromTokenDecimals
        }&destToken=${toTokenAddress
        }&destDecimals=${toTokenDecimals
        }&amount=${swapAmount.toString()
        }&side=${side}&network=${POLYGON_CHAIN_ID
        }&userAddress=${broker.proxy.address}`
    console.log("Price Url", url)
    const responseQuote = await axios.get(
        url
    )
    console.log("priceRoute", responseQuote.data.priceRoute)
    console.log("bestRoute", responseQuote.data.priceRoute.bestRoute[0].swaps[0].swapExchanges)
    const txUrl = `https://apiv5.paraswap.io/transactions/${POLYGON_CHAIN_ID}?ignoreChecks=true&ignoreGasEstimate=true&onlyParams=false`
    console.log("TX url", txUrl)

    const slippageAndAmount = side === 'SELL' ? {
        srcAmount: responseQuote.data.priceRoute.srcAmount,
        slippage: '100'
      } : {
        destAmount: responseQuote.data.priceRoute.destAmount,
        slippage: '100'
      }

    const txParams = {
        priceRoute: responseQuote.data.priceRoute,
        srcToken: fromToken,
        srcDecimals: fromTokenDecimals,
        destToken: toTokenAddress,
        destDecimals: toTokenDecimals,
        partner: 'paraswap.io',
        side,
        userAddress: broker.proxy.address,
        txOrigin: broker.proxy.address,
        receiver: broker.proxy.address,
        ...slippageAndAmount
    }
    console.log("tx Params", txParams)
    const responseTx = await axios.post(
        txUrl,
        txParams
    ) // .catch(e=> console.log(e))
    if (side === 'BUY') {
        console.log("TX", responseTx.data)
        const params = {
            baseAsset: toTokenAddress, // the asset to interact with
            target: paraswapRouter,
            marginTradeType: 0, // margin open
            interestRateModeIn: InterestRateMode.VARIABLE, // the borrow mode
            interestRateModeOut: 0, // unused
            withdrawMax: false
        }
        console.log("Executing trade", responseTx?.data.data)
        await balancerModule.executeOnBalancer(
            fromToken,
            amountToBorrowMax,
            params,
            responseTx?.data.data
        )
    } else {
        const params = {
            baseAsset: toTokenAddress, // the asset to interact with
            target: paraswapRouter,
            marginTradeType: 0, // margin open
            interestRateModeIn: InterestRateMode.VARIABLE, // the borrow mode
            interestRateModeOut: 0, // unused
            withdrawMax: false
        }
        console.log("Executing trade")
        await balancerModule.executeOnBalancer(
            fromToken,
            responseQuote.data.priceRoute.srcAmount,
            params,
            responseTx?.data.data
        )
    }

})
