import { parseUnits } from "ethers/lib/utils";
import { aaveAddresses, generalAddresses, uniswapAddresses } from "../deploy/00_addresses";
import { addressesTokens } from "../scripts/aaveAddresses";
import { OneDeltaQuoterMantle, OneDeltaQuoterMantle__factory, } from "../types";
import { encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount } from "./uniswap-v3/periphery/shared/constants";
import { encodePath } from "./uniswap-v3/periphery/shared/path";
const { ethers } = require("hardhat");

const MANTLE_CHAIN_ID = 5000;

const usdtAddress = '0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE'
const wbtcAddress = '0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2'
const usdcAddress = addressesTokens.USDC[MANTLE_CHAIN_ID]
const wmaticAddress = generalAddresses.WETH[MANTLE_CHAIN_ID]
const wethAddress = addressesTokens.WETH[MANTLE_CHAIN_ID]

let quoter: OneDeltaQuoterMantle
before(async function () {
    const [signer] = await ethers.getSigners();
    console.log("deploy quoter")
    quoter = await new OneDeltaQuoterMantle__factory(signer).deploy()
})


it("Test FusionXV3 single", async function () {

    const tokenIn = wethAddress
    const tokenOut = wmaticAddress
    const fee = FeeAmount.LOW
    const pId = 0;
    const amountIn = parseUnits('1', 18)
    console.log("Test Quoter single EI Uni:", tokenIn, tokenOut, pId)
    const quote = await quoter.callStatic.quoteExactInputSingleV3(
        tokenIn,
        tokenOut,
        fee,
        pId,
        amountIn
    )

    console.log("Quote Uni", quote.toString())


})


it("Test Agni single", async function () {

    const tokenIn = wethAddress
    const tokenOut = wmaticAddress
    const fee = FeeAmount.LOW
    let pId = 1;
    let amountIn = parseUnits('0.1', 18)

    console.log("Test Quoter single EI Quick:", tokenIn, tokenOut, pId)
    const quote = await quoter.callStatic.quoteExactInputSingleV3(
        tokenIn,
        tokenOut,
        fee,
        pId,
        amountIn
    )
    console.log("Quote Quick", quote.toString())

})


it("Test Sushiswap single", async function () {

    const tokenIn = usdcAddress
    const tokenOut = wmaticAddress
    const fee = FeeAmount.MEDIUM
    let pId = 2;
    let amountIn = parseUnits('100', 6)

    console.log("Test Quoter single EI Quick:", tokenIn, tokenOut, pId)
    const quote = await quoter.callStatic.quoteExactInputSingleV3(
        tokenIn,
        tokenOut,
        fee,
        pId,
        amountIn
    )
    console.log("Quote Quick", quote.toString())

})

it("Test Quick and Uni Mix", async function () {

    const tokenIn = usdtAddress
    const tokenOut = wmaticAddress
    const fee = FeeAmount.MEDIUM
    let pId = 1;
    let amountIn = parseUnits('100', 18)

    console.log("Test Quoter Mix:", tokenIn, tokenOut, pId)

    const route = encodeQuoterPathEthers(
        [usdtAddress, wmaticAddress, wethAddress],
        [FeeAmount.MEDIUM, 0],
        [0, 1]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})


it("Test Quick, Uni, Quick V2 Mix", async function () {

    const amountIn = parseUnits('100', 18)

    console.log("Test Quoter single EI Quick:")

    const route = encodeQuoterPathEthers(
        [usdtAddress, wmaticAddress, wethAddress, usdcAddress],
        [FeeAmount.MEDIUM, 0, 0],
        [0, 1, 50]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})

it("Test Quick, Sushi, Quick V2 Mix", async function () {

    const amountIn = parseUnits('100', 18)

    console.log("Test Quoter single EI Quick:")

    const route = encodeQuoterPathEthers(
        [usdtAddress, wmaticAddress, wethAddress, usdcAddress],
        [0, FeeAmount.LOW, 0],
        [1, 2, 51]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})


it("Test Quick, Uni, Quick V2 Mix Exact Out", async function () {

    const amountOut = parseUnits('100', 18)

    console.log("Test Quoter single EO Quick:")

    const route = encodeQuoterPathEthers(
        [usdtAddress, wmaticAddress, wethAddress, usdcAddress],
        [FeeAmount.MEDIUM, 0, 0],
        [0, 1, 50]
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amountOut
    )
    console.log("Quote Mixed", quote.toString())
})

it("Test Quick, Sushi, Quick V2 Mix Exact Out", async function () {

    const amountOut = parseUnits('1', 18)

    console.log("Test Quoter single EO Quick:")

    const route = encodeQuoterPathEthers(
        [usdtAddress, wmaticAddress, wethAddress, usdcAddress],
        [0, FeeAmount.LOW, 0],
        [1, 2, 51]
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amountOut
    )
    console.log("Quote Mixed", quote.toString())
})