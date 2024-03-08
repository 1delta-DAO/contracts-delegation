import { parseUnits } from "ethers/lib/utils";
import { OneDeltaQuoterMantle, OneDeltaQuoterMantle__factory, } from "../types";
import { encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
const { ethers } = require("hardhat");

const usdt = '0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE'
const usdc = '0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9'
const wmt = '0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8'
const USDY = '0x5bE26527e817998A7206475496fDE1E68957c5A6';
const MUSD = '0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3';

let quoter: OneDeltaQuoterMantle
before(async function () {
    const [signer] = await ethers.getSigners();
    console.log("deploy quoter")
    quoter = await new OneDeltaQuoterMantle__factory(signer).deploy()
})

it("Test stratum 3USD EI single stable (standard)", async function () {

    const amountIn = parseUnits('2', 6)
    const route = encodeQuoterPathEthers(
        [usdc, usdt],
        [0],
        [102]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Single USDC->USDT", quote.toString())

})

it("Test stratum EI single stable USDY->USDT", async function () {

    const amountIn = parseUnits('1', 18)
    const route = encodeQuoterPathEthers(
        [USDY, usdt],
        [0],
        [102]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote Single USDY->USDT", quote.toString())
})

it("Test stratum EI multi stable USDY out", async function () {

    const amountIn = parseUnits('1', 18)
    const route = encodeQuoterPathEthers(
        [wmt, usdc, USDY],
        [500, 0],
        [1, 102]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote WMNT->USDC->USDY", quote.toString())

})

it("Test stratum EI multi stable MUSD out", async function () {

    const amountIn = parseUnits('1', 18)
    const route = encodeQuoterPathEthers(
        [wmt, usdc, MUSD],
        [500, 0],
        [1, 102]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote WMNT->USDC->MUSD", quote.toString())

})

it("Test stratum EI multi stable USDY in", async function () {

    const amountIn = '1913773297791126575175' //  parseUnits('1', 18)
    const route = encodeQuoterPathEthers(
        [USDY, usdc, wmt],
        [0, 500],
        [102, 1]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote USDY->WMNT->USDC", quote.toString())
})

it("Test stratum EI multi stable MUSD in", async function () {

    const amountIn = parseUnits('1', 18)
    const route = encodeQuoterPathEthers(
        [MUSD, usdc, wmt],
        [0, 500],
        [102, 1]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        route,
        amountIn
    )
    console.log("Quote WMNT->USDC->USDY", quote.toString())
})
