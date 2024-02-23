import { parseUnits } from "ethers/lib/utils";
import { generalAddresses } from "../deploy/polygon_addresses";
import { addressesTokens } from "../scripts/aaveAddresses";
import { OneDeltaQuoterMantle, OneDeltaQuoterMantle__factory, } from "../types";
import { encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount } from "./uniswap-v3/periphery/shared/constants";
const { ethers } = require("hardhat");

const MANTLE_CHAIN_ID = 5000;

const usdt = '0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE'
const weth = '0xdeaddeaddeaddeaddeaddeaddeaddeaddead1111'
const usdc = '0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9'
const wmt = '0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8'
const btc = '0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2'
const grai = '0x894134a25a5faC1c2C26F1d8fBf05111a3CB9487'
const cleo = '0xC1E0C8C30F251A07a894609616580ad2CEb547F2'


let quoter: OneDeltaQuoterMantle
before(async function () {
    const [signer] = await ethers.getSigners();
    console.log("deploy quoter")
    quoter = await new OneDeltaQuoterMantle__factory(signer).deploy()
})


it.only("Test stratum EI single stable", async function () {

    const amountIn = parseUnits('2', 6)
    const route = encodeQuoterPathEthers(
        [usdc, usdt],
        [0],
        [57]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Single USDC->USDT", quote.toString())

})


it.only("Test stratum EO single stable", async function () {

    const amountOut = '1999192'
    const route = encodeQuoterPathEthers(
        [usdc, usdt].reverse(),
        [0],
        [57]
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amountOut
    )
    console.log("Quote Single USDC->USDT", quote.toString())

})

it.only("Test stratum EI multi stable", async function () {

    const amountIn = parseUnits('2', 18)
    const route = encodeQuoterPathEthers(
        [wmt, usdc, usdt],
        [500, 0],
        [1, 57]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote WMNT->USDT", quote.toString())

})

it.only("Test stratum EO multi stable", async function () {

    const amount = '1585152'
    const route = encodeQuoterPathEthers(
        [wmt, usdc, usdt].reverse(),
        [500, 0].reverse(),
        [1, 57].reverse()
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amount
    )
    console.log("Quote Mixed", quote.toString())

})

// it.only("Test fusion cleo single stable exact out", async function () {
//     // this is the output of the previous quote
//     const amountOut = '1999003817240511182'
//     const pathDelta = encodeQuoterPathEthers(
//         [grai, usdc],
//         [0],
//         [55]
//     )


//     const quote = await quoter.callStatic.quoteExactOutput(
//         pathDelta, amountOut
//     )
//     console.log("Quote single", quote.toString())
// })

// it.only("Test cleo EI single volatile", async function () {

//     const amountIn = parseUnits('1', 18)
//     const route = encodeQuoterPathEthers(
//         [wmt, cleo],
//         [0],
//         [54]
//     )
//     const quote = await quoter.callStatic.quoteExactInput(
//         route,
//         amountIn
//     )
//     console.log("Quote Mixed", quote.toString())

// })

// it.only("Test fusion cleo volatile exact out", async function () {

//     const amountOut = '4195993827708820'

//     const pathDelta = encodeQuoterPathEthers(
//         [cleo, wmt],
//         [0],
//         [54]
//     )


//     const quote = await quoter.callStatic.quoteExactOutput(
//         pathDelta, amountOut
//     )
//     console.log("Quote single", quote.toString())
// })
