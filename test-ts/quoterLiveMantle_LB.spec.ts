import { parseUnits } from "ethers/lib/utils";
import { OneDeltaQuoterMantle, OneDeltaQuoterMantle__factory, } from "../types";
import { encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
const { ethers } = require("hardhat");

const usdtAddress = '0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE'
const usde = '0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34'
const btc = '0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2'

let quoter: OneDeltaQuoterMantle
before(async function () {
    const [signer] = await ethers.getSigners();
    console.log("deploy quoter")
    quoter = await new OneDeltaQuoterMantle__factory(signer).deploy()
})


it("Test Moe LB EI", async function () {

    const amountIn = parseUnits('450', 18)
    const route = encodeQuoterPathEthers(
        [usde, usdtAddress],
        [1],
        [103]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})

it("Test Moe LB EO", async function () {

    const amountOut = parseUnits('450', 6)
    const route = encodeQuoterPathEthers(
        [usdtAddress, usde],
        [1],
        [103]
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amountOut
    )
    console.log("Quote Mixed", quote.toString())

})


it("Test Moe EI Mix", async function () {

    const amountIn = parseUnits('1', 18)
    const route = encodeQuoterPathEthers(
        [usde, usdtAddress, btc ],
        [1, 500],
        [103, 0]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})

it("Test fusion moe mix exact out", async function () {

    const amount = '100000'

    const pathDelta = encodeQuoterPathEthers(
        [btc, usdtAddress, usde],
        [500, 1],
        [0, 103]
    )


    const quote = await quoter.callStatic.quoteExactOutput(
        pathDelta, amount
    )
    console.log("Quote single", quote.toString())
})

