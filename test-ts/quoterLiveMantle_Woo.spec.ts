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


it("Test Woo EI Large", async function () {

    const amountIn = parseUnits('45000', 18)
    const route = encodeQuoterPathEthers(
        [wmt, usdc],
        [0,],
        [101]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Mixed", quote.toString())

})

