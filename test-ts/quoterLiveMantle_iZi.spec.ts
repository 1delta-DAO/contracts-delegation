import { parseUnits } from "ethers/lib/utils";
import { generalAddresses } from "../deploy/polygon_addresses";
import { addressesTokens } from "../scripts/aaveAddresses";
import { OneDeltaQuoterMantle, OneDeltaQuoterMantle__factory, } from "../types";
import { encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount } from "./uniswap-v3/periphery/shared/constants";
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


it("Test iZi single", async function () {

    const tokenIn = wmt
    const tokenOut = weth
    const fee = FeeAmount.LOW
    const pId = 0;
    const amountIn = parseUnits('1', 18)
    const quote = await quoter.callStatic.quoteExactInputSingle_iZi(
        tokenIn,
        tokenOut,
        fee,
        amountIn
    )
    console.log("Quote Fusion", quote.toString())
})

it("Test iZi Exact Out Single", async function () {

    const amountOut = 9999  // parseUnits('0.1', 18)


    const quote = await quoter.callStatic.quoteExactOutputSingle_iZi(
        wmt,
        weth,
        FeeAmount.LOW,
        amountOut
    )
    console.log("Quote single", quote.toString())
})


it("Test nex exactout", async function () {
    // UDSC->WMNT->USDT->WBTC 
    // 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9->0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8->0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE->0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2
    //  10000_FUSIONX_V3->500_FUSIONX_V3->500_FUSIONX_V3 
    //  0xcabae6f6ea1ecab08ad02fe02ce9a44f09aebfa20001f400201eba5cc46d216ce6dc03f6a759e8e766e956ae0001f40078c1b0c915c4faa5fffa6cabf0219da63d7f4cb80027100009bc4e0d864854c6afb6eb9a9cdf58ac190d0df9

    const amount = '100000'

    const pathDelta = encodeQuoterPathEthers(
        [btc, usdtAddress, wmt, usdc],
        [500, 500, 10000],
        [0, 0, 0]
    )


    const quote = await quoter.callStatic.quoteExactOutput(
        pathDelta, amount
    )
    console.log("Quote single", quote.toString())
})

it.only("Test Swapsicle Exact Out", async function () {


    const slush = '0x8309bc8bb43fb54db02da7d8bf87192355532829'
    const amount =  parseUnits('1', 18)

    const pathDelta = encodeQuoterPathEthers(
        [slush, wmt, usdc],
        [0, 0],
        [3, 3]
    )


    const quote = await quoter.callStatic.quoteExactOutput(
        pathDelta, amount
    )
    console.log("Quote single", quote.toString())
})


it.only("Test Swapsicle Exact In", async function () {


    const slush = '0x8309bc8bb43fb54db02da7d8bf87192355532829'
    const amount =  parseUnits('1', 18)

    const pathDelta = encodeQuoterPathEthers(
        [slush, wmt, usdc],
        [0, 1],
        [3, 3]
    )


    const quote = await quoter.callStatic.quoteExactInput(
        pathDelta, amount
    )
    console.log("Quote single", quote.toString())
})



// it("Test Fusion V3 Exact Out Single WBTC", async function () {

//     const amountOut = parseUnits('1', 18)



//     const routeDirect = encodeQuoterPathEthers(
//         [usdc, btc].reverse(),
//         [2500].reverse(),
//         [0].reverse()
//     )

//     const quote = await quoter.callStatic.quoteExactOutput(
//         routeDirect,
//         amountOut
//     )
//     console.log("Quote single", quote.toString())
// })


// it("Test Fusion V3 Exact Out", async function () {

//     const amountOut = parseUnits('1', 18)


//     const route = encodeQuoterPathEthers(
//         [usdc, usdtAddress, weth].reverse(),
//         [100, 500].reverse(),
//         [0, 0]
//     )
//     const quote = await quoter.callStatic.quoteExactOutput(
//         route,
//         amountOut
//     )
//     console.log("Quote Mixed", quote.toString())
// })


// it.only("Test Fusion V3 Exact Out mixed v2 v3", async function () {

//     const amountOut = 1000 // parseUnits('0.1', 8)


//     const route = encodeQuoterPathEthers(
//         [usdc, wmt, usdc, btc].reverse(),
//         [500, 10000, 0].reverse(),
//         [0, 0, 50].reverse()
//     )
//     const quote = await quoter.callStatic.quoteExactOutput(
//         route,
//         amountOut
//     )
//     console.log("Quote Mixed", quote.toString())
// })


// it("Test Fusion V3 Exact Out 2", async function () {

//     const amountOut = parseUnits('4000', 18)


//     const route = encodeQuoterPathEthers(
//         [usdtAddress, wmt].reverse(),
//         [500].reverse(),
//         [0]
//     )
//     const quote = await quoter.callStatic.quoteExactOutput(
//         route,
//         amountOut
//     )
//     console.log("Quote Mixed", quote.toString())
// })

// it("Test Fusion V3 Exact Out 3", async function () {

//     const amountOut = parseUnits('4000', 18)


//     const route = encodeQuoterPathEthers(
//         [usdtAddress, wmt].reverse(),
//         [500].reverse(),
//         [0]
//     )
//     const quote = await quoter.callStatic.quoteExactOutput(
//         route,
//         amountOut
//     )
//     console.log("Quote Mixed", quote.toString())
// })


// it("Test Fusion V3 Exact Out custorm", async function () {

//     const amountOut = parseUnits('1', 18)


//     const route = '0xdeaddeaddeaddeaddeaddeaddeaddeaddead11110001f400201eba5cc46d216ce6dc03f6a759e8e766e956ae0027100009bc4e0d864854c6afb6eb9a9cdf58ac190d0df9'
//     const quote = await quoter.callStatic.quoteExactOutput(
//         route,
//         amountOut
//     )
//     console.log("Quote Mixed", quote.toString())
// })


/**
it("Test Agni single", async function () {

    const tokenIn = wethAddress
    const tokenOut = wmaticAddress
    const fee = FeeAmount.LOW
    let pId = 1;
    let amountIn = parseUnits('0.1', 18)


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