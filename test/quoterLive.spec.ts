import { parseUnits } from "ethers/lib/utils";
import { aaveAddresses, generalAddresses, uniswapAddresses } from "../deploy/00_addresses";
import {  addressesTokens } from "../scripts/aaveAddresses";
import {  OneDeltaQuoter__factory } from "../types";
import { FeeAmount } from "./uniswap-v3/periphery/shared/constants";
const { ethers } = require("hardhat");

const POLYGON_CHAIN_ID = 137;

const aavePool = aaveAddresses.v3pool[POLYGON_CHAIN_ID]
const balancerV2Vault = '0xBA12222222228d8Ba445958a75a0704d566BF2C8'
const crvAddress = '0x172370d5Cd63279eFa6d502DAB29171933a610AF'
const wbtcAddress = '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6'
const uniswapFactoryAddress = uniswapAddresses.factory[POLYGON_CHAIN_ID]
const usdcAddress = addressesTokens.USDC[POLYGON_CHAIN_ID]
const wmaticAddress = generalAddresses.WETH[POLYGON_CHAIN_ID]
const wethAddress = addressesTokens.WETH[POLYGON_CHAIN_ID]


it("Test quoter", async function () {
    const [signer] = await ethers.getSigners();
    const chainId = await signer.getChainId()
    console.log("usdcAddress", usdcAddress)

    const quoter = await new OneDeltaQuoter__factory(signer).deploy()

    const tokenIn = crvAddress
    const tokenOut = wmaticAddress
    const fee = FeeAmount.MEDIUM
    const pId = 0;
    const amountIn = parseUnits('1', 18)
    console.log("Test Quoter 1:", tokenIn, tokenOut, pId)
    const quote = await quoter.callStatic.quoteExactInputSingleV3(
        tokenIn,
        tokenOut,
        fee,
        pId,
        amountIn
    )

    console.log("TEST", quote.toString())

})
