import { parseUnits } from "ethers/lib/utils";
import { OneDeltaQuoterMantle, OneDeltaQuoterMantle__factory, } from "../types";
import { encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount } from "./uniswap-v3/periphery/shared/constants";
const { ethers } = require("hardhat");


const usdtAddress = '0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE'

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

it.only("Test KTX Single", async function () {

    const amountIn = parseUnits('1', 18)

    console.log("Test Quoter single EI KTX:")

    const route = encodeQuoterPathEthers(
        [weth, btc],
        [0],
        [104]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})

// it.only("Test Fusion V3 & Butter Exact Out mixed v3", async function () {

//     const amountOut =  parseUnits('0.1', 18)

//     console.log("Test Quoter multi EO Fusion v2 v3:")

//     const route = encodeQuoterPathEthers(
//         [usdc, wmt, weth].reverse(),
//         [500, 500].reverse(),
//         [0, 3].reverse()
//     )
//     const quote = await quoter.callStatic.quoteExactOutput(
//         route,
//         amountOut
//     )
//     console.log("Quote Mixed", quote.toString())
// })


// it("Test Butter Exact Out 2", async function () {

//     const amountOut = parseUnits('4000', 18)

//     console.log("Test Quoter multi EO Fusion:")

//     const route = encodeQuoterPathEthers(
//         [weth, wmt].reverse(),
//         [500].reverse(),
//         [3]
//     )
//     const quote = await quoter.callStatic.quoteExactOutput(
//         route,
//         amountOut
//     )
//     console.log("Quote Mixed", quote.toString())
// })

// it("Test Fusion V3 Exact Out 3", async function () {

//     const amountOut = parseUnits('4000', 18)

//     console.log("Test Quoter multi EO Fusion:")

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

//     console.log("Test Quoter multi EO Fusion:")

//     const route = '0xdeaddeaddeaddeaddeaddeaddeaddeaddead11110001f400201eba5cc46d216ce6dc03f6a759e8e766e956ae0027100009bc4e0d864854c6afb6eb9a9cdf58ac190d0df9'
//     const quote = await quoter.callStatic.quoteExactOutput(
//         route,
//         amountOut
//     )
//     console.log("Quote Mixed", quote.toString())
// })
