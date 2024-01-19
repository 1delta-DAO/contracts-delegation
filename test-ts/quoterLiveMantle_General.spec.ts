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

const axlFrax = '0x406Cde76a3fD20e48bc1E0F60651e60Ae204B040'
const axlUsdc = '0xEB466342C4d449BC9f53A865D5Cb90586f405215'
const sFrax = '0xf3602C5A7f625181659445C8dDDde73dA15c22e3'
const sFraxETH = '0x4f74ca4a686203a5D4eBF6E8868c5eBC450bf283'

let quoter: OneDeltaQuoterMantle
before(async function () {
    const [signer] = await ethers.getSigners();
    console.log("deploy quoter")
    quoter = await new OneDeltaQuoterMantle__factory(signer).deploy()
})



it("Test V2 EI Moe Mix", async function () {

    const amount = '1000000'
    const route = encodeQuoterPathEthers(
        [usdc, wmt, btc],
        [250, 0],
        [4, 50]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amount
    )
    console.log("Quote Mixed", quote.toString())

})


it("Test V2 EO Moe Mix", async function () {

    const amount = '2423'
    const route = encodeQuoterPathEthers(
        [usdc, wmt, btc].reverse(),
        [250, 0].reverse(),
        [4, 50].reverse()
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amount
    )
    console.log("Quote Mixed", quote.toString())

})



it("Test V2 EI Fusion", async function () {

    const amount = '1000000000'
    const route = encodeQuoterPathEthers(
        [usdc, wmt, usdt],
        [0, 250],
        [51, 4]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amount
    )
    console.log("Quote Mixed", quote.toString())

})

it("Test FusionV2 EI single stable", async function () {

    const amount = '996097695'
    const route = encodeQuoterPathEthers(
        [usdc, wmt, usdt].reverse(),
        [0, 250].reverse(),
        [51, 4].reverse()
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amount
    )
    console.log("Quote Mixed", quote.toString())

})
