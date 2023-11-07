import { parseUnits } from "ethers/lib/utils";
import { aaveAddresses, generalAddresses, uniswapAddresses } from "../deploy/polygon_addresses";
import { addressesTokens } from "../scripts/aaveAddresses";
import { OneDeltaQuoter, OneDeltaQuoter__factory, Quoter__factory, UniswapInterfaceMulticall__factory } from "../types";
import { encodeQuoterPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount } from "./uniswap-v3/periphery/shared/constants";
import { encodePath } from "./uniswap-v3/periphery/shared/path";
const { ethers } = require("hardhat");

const POLYGON_CHAIN_ID = 137;

const aavePool = aaveAddresses.v3pool[POLYGON_CHAIN_ID]
const balancerV2Vault = '0xBA12222222228d8Ba445958a75a0704d566BF2C8'
const crvAddress = '0x172370d5Cd63279eFa6d502DAB29171933a610AF'
const wbtcAddress = '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6'
const uniswapFactoryAddress = uniswapAddresses.factory[POLYGON_CHAIN_ID]
const usdcAddress = addressesTokens.USDC[POLYGON_CHAIN_ID]
const wmaticAddress = generalAddresses.WETH[POLYGON_CHAIN_ID]
const wethAddress = addressesTokens.WETH[POLYGON_CHAIN_ID]

let quoter: OneDeltaQuoter
before(async function () {
    const [signer] = await ethers.getSigners();
    console.log("deploy quoter")
    quoter = await new OneDeltaQuoter__factory(signer).deploy()
})

it("Test custom", async function () {
    const [signer] = await ethers.getSigners();


    const tokenIn = crvAddress
    const tokenOut = wmaticAddress;
    console.log("Test Quoter single EI Uni:", tokenIn, tokenOut)
    const path = encodeQuoterPathEthers(
        [wethAddress, usdcAddress],
        [100],
        [0]
    )
    const quote = await quoter.callStatic.quoteExactInput(
        path,
        '0x22b1c8c1227a0000'
    )
    const encoded = quoter.interface.encodeFunctionResult('quoteExactInput', [quote.toString()])
    console.log("Quote Uni", quote.toString(), encoded)
})

it("Test custom multicall", async function () {
    const [signer] = await ethers.getSigners();


    const tokenIn = crvAddress
    const tokenOut = wmaticAddress;
    console.log("Test Quoter single Mmulticall Uni:", tokenIn, tokenOut)
    const multi = await new UniswapInterfaceMulticall__factory(signer).deploy()

    const pathDelta = encodeQuoterPathEthers(
        [wethAddress, usdcAddress],
        [100],
        [0]
    )
    const callData = quoter.interface.encodeFunctionData('quoteExactInput', [
        pathDelta,
        '0x22b1c8c1227a0000'
    ])

    const path = encodePath([wethAddress, usdcAddress], [100])
    const quoterUni = await new Quoter__factory(signer).attach('0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6')
    const calldataUni = quoterUni.interface.encodeFunctionData('quoteExactInput' as any, [path, '0x22b1c8c1227a0000'])
    // const test = await quoterUni.callStatic.quoteExactInput(path, '0x22b1c8c1227a0000')
    // console.log("UNI", test.toString())
    console.log("TE")
    const param = {
        target: quoter.address,
        callData,
        gasLimit: 7_500_000
    }
    const x = await multi.callStatic.multicall([param])
    const param2 = {
        target: quoterUni.address,
        callData: calldataUni,
        gasLimit: 7_500_000
    }
    const x2 = await multi.callStatic.multicall([param2])
    console.log("x2", x2.returnData[0].success, x2.returnData[0].returnData)
    const cc = x[1]?.[0]?.[2]
    console.log("res", cc)
    console.log("x", x.returnData[0].success, x.returnData[0].returnData)
    const res = quoter.interface.decodeFunctionResult('quoteExactInput', x.returnData[0].returnData)
    console.log("Quote Uni", res.toString())
})


it("Test Uni single", async function () {

    const tokenIn = crvAddress
    const tokenOut = wmaticAddress
    const fee = FeeAmount.MEDIUM
    const pId = 0;
    const amountIn = parseUnits('100', 18)
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


it("Test Quickswap single", async function () {

    const tokenIn = crvAddress
    const tokenOut = wmaticAddress
    const fee = FeeAmount.MEDIUM
    let pId = 1;
    let amountIn = parseUnits('100', 18)

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

    const tokenIn = crvAddress
    const tokenOut = wmaticAddress
    const fee = FeeAmount.MEDIUM
    let pId = 1;
    let amountIn = parseUnits('100', 18)

    console.log("Test Quoter Mix:", tokenIn, tokenOut, pId)

    const route = encodeQuoterPathEthers(
        [crvAddress, wmaticAddress, wethAddress],
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
        [crvAddress, wmaticAddress, wethAddress, usdcAddress],
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
        [crvAddress, wmaticAddress, wethAddress, usdcAddress],
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
        [crvAddress, wmaticAddress, wethAddress, usdcAddress],
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
        [crvAddress, wmaticAddress, wethAddress, usdcAddress],
        [0, FeeAmount.LOW, 0],
        [1, 2, 51]
    )
    const quote = await quoter.callStatic.quoteExactOutput(
        route,
        amountOut
    )
    console.log("Quote Mixed", quote.toString())
})