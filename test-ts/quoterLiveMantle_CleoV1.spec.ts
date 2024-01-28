import { parseUnits } from "ethers/lib/utils";
import { generalAddresses } from "../deploy/polygon_addresses";
import { addressesTokens } from "../scripts/aaveAddresses";
import { OneDeltaQuoterMantle, OneDeltaQuoterMantle__factory, } from "../types";
import { encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount } from "./uniswap-v3/periphery/shared/constants";
const { ethers } = require("hardhat");

const MANTLE_CHAIN_ID = 5000;

const usdt = '0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE'
const wbtcAddress = '0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2'
const usdcAddress = addressesTokens.USDC[MANTLE_CHAIN_ID]
const wmaticAddress = generalAddresses.WETH[MANTLE_CHAIN_ID]
const wethAddress = addressesTokens.WETH[MANTLE_CHAIN_ID]


const weth = '0xdeaddeaddeaddeaddeaddeaddeaddeaddead1111'
const usdc = '0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9'
const wmt = '0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8'
const btc = '0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2'
const grai = '0x894134a25a5faC1c2C26F1d8fBf05111a3CB9487'
const cleo = '0xC1E0C8C30F251A07a894609616580ad2CEb547F2'

const axlFrax = '0x406Cde76a3fD20e48bc1E0F60651e60Ae204B040'
const axlUsdc = '0xEB466342C4d449BC9f53A865D5Cb90586f405215'
const sFrax = '0xf3602C5A7f625181659445C8dDDde73dA15c22e3'
const sFraxETH = '0x4f74ca4a686203a5D4eBF6E8868c5eBC450bf283'

let quoter: OneDeltaQuoterMantle
before(async function () {
    const [signer] = await ethers.getSigners();
    console.log("deploy quoter")
    quoter = await new OneDeltaQuoterMantle__factory(signer).attach('0x358d9f63726904cF2d01995B967179B370882367')
})


it.only("Test cleo EI single stable", async function () {

    const amountIn = parseUnits('2', 6)
    const route = encodeQuoterPathEthers(
        [usdc, grai],
        [0],
        [55]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})

it.only("Test cleo EI multi stable", async function () {

    const amountIn = parseUnits('2', 6)
    const route = encodeQuoterPathEthers(
        [usdt, usdc, grai],
        [100, 0],
        [1, 55]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})

it.only("Test cleo E) multi stable", async function () {

    const amount = '1998243815791008678'
    const route = encodeQuoterPathEthers(
        [usdt, usdc, grai].reverse(),
        [100, 0].reverse(),
        [1, 55].reverse()
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amount
    )
    console.log("Quote Mixed", quote.toString())

})

it.only("Test fusion cleo single stable exact out", async function () {
    // this is the output of the previous quote
    const amountOut = '1999003817240511182'
    const pathDelta = encodeQuoterPathEthers(
        [grai, usdc],
        [0],
        [55]
    )


    const quote = await quoter.callStatic.quoteExactOutput(
        pathDelta, amountOut
    )
    console.log("Quote single", quote.toString())
})

it.only("Test cleo EI single volatile", async function () {

    const amountIn = parseUnits('1', 18)
    const route = encodeQuoterPathEthers(
        [wmt, cleo],
        [0],
        [54]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})

it.only("Test fusion cleo volatile exact out", async function () {

    const amountOut = '4195993827708820'

    const pathDelta = encodeQuoterPathEthers(
        [cleo, wmt],
        [0],
        [54]
    )


    const quote = await quoter.callStatic.quoteExactOutput(
        pathDelta, amountOut
    )
    console.log("Quote single", quote.toString())
})



it("Test Velo EI Mix", async function () {

    const amountIn = parseUnits('1', 6)
    const route = encodeQuoterPathEthers(
        [axlUsdc, axlFrax, sFrax, sFraxETH],
        [0, 0, 0],
        [53, 52, 52]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})

it("Test fusion Velo mix exact out", async function () {
    // this is the output from before
    const amountOut = '407269547185617'

    const pathDelta = encodeQuoterPathEthers(
        [axlUsdc, axlFrax, sFrax, sFraxETH].reverse(),
        [0, 0, 0].reverse(),
        [53, 52, 52].reverse()
    )


    const quote = await quoter.callStatic.quoteExactOutput(
        pathDelta, amountOut
    )
    console.log("Quote single", quote.toString())
})

