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


const weth = '0xdeaddeaddeaddeaddeaddeaddeaddeaddead1111'
const usdc = '0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9'
const wmt = '0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8'
const btc = '0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2'

let quoter: OneDeltaQuoterMantle
before(async function () {
    const [signer] = await ethers.getSigners();
    console.log("deploy quoter")
    quoter = await new OneDeltaQuoterMantle__factory(signer).deploy()
})


// it("Test FusionXV3 single", async function () {

//     const tokenIn = wethAddress
//     const tokenOut = wmaticAddress
//     const fee = FeeAmount.LOW
//     const pId = 0;
//     const amountIn = parseUnits('1', 18)
//     console.log("Test Quoter single EI Uni:", tokenIn, tokenOut, pId)
//     const quote = await quoter.callStatic.quoteExactInputSingleV3(
//         tokenIn,
//         tokenOut,
//         fee,
//         pId,
//         amountIn
//     )
//     console.log("Quote Fusion", quote.toString())
// })

it("Test Fusion V3 Exact Out Single", async function () {

    const amountOut = parseUnits('1', 18)

    console.log("Test Quoter single EO Fusion:")

    const quote = await quoter.callStatic.quoteExactOutputSingleV3(
        wmt,
        weth,
        2500,
        0,
        amountOut
    )
    console.log("Quote single", quote.toString())
})

it("Test Fusion V3 Exact Out", async function () {

    const amountOut = parseUnits('1', 18)

    console.log("Test Quoter multi EO Fusion:")

    const route = encodeQuoterPathEthers(
        [usdc, usdtAddress, weth].reverse(),
        [100, 500].reverse(),
        [0, 0]
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amountOut
    )
    console.log("Quote Mixed", quote.toString())
})


it("Test Fusion V3 Exact Out 2", async function () {

    const amountOut = parseUnits('4000', 18)

    console.log("Test Quoter multi EO Fusion:")

    const route = encodeQuoterPathEthers(
        [usdtAddress, wmt].reverse(),
        [500].reverse(),
        [0]
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amountOut
    )
    console.log("Quote Mixed", quote.toString())
})

it("Test Fusion V3 Exact Out 3", async function () {

    const amountOut = parseUnits('4000', 18)

    console.log("Test Quoter multi EO Fusion:")

    const route = encodeQuoterPathEthers(
        [usdtAddress, wmt].reverse(),
        [500].reverse(),
        [0]
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amountOut
    )
    console.log("Quote Mixed", quote.toString())
})


it.only("Test Fusion V3 Exact Out custorm", async function () {

    const amountOut = parseUnits('1', 18)

    console.log("Test Quoter multi EO Fusion:")

    const route = '0xdeaddeaddeaddeaddeaddeaddeaddeaddead11110001f400201eba5cc46d216ce6dc03f6a759e8e766e956ae0027100009bc4e0d864854c6afb6eb9a9cdf58ac190d0df9'
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amountOut
    )
    console.log("Quote Mixed", quote.toString())
})


/**
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
 */