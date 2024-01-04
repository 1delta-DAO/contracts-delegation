import { addressesTokens } from "../../../scripts/aaveAddresses";
import { Comet, CometFlashAggregatorPolygon__factory, Comet__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, FlashAggregator__factory, OneDeltaQuoter, OneDeltaQuoter__factory } from "../../../types";
import { encodeAggregatorPathEthers } from "../shared/aggregatorPath";
import { FeeAmount } from "../../uniswap-v3/periphery/shared/constants";
import { cometAddress } from "../../../scripts/comet/cometAddresses";
import { impersonateAccount, setCode } from "@nomicfoundation/hardhat-network-helpers";
import { cometBrokerAddresses } from "../../../deploy/polygon_addresses";
import { SignerWithAddress } from "hardhat-deploy-ethers/signers";
import { network } from "hardhat";
const { ethers } = require("hardhat");

const POLYGON_CHAIN_ID = 137;

const usdcAddress = addressesTokens.USDC[POLYGON_CHAIN_ID]
const wethAddress = addressesTokens.WETH[POLYGON_CHAIN_ID]

const providedData = {
    "blockNumber": "49463469",
    "amount": "1731376868",
    "amountDecimals": "1731.376868",
    "quote": "957852396474976392",
    "quoteDecimals": "0.957852396474976392",
    "quoteGasAdjusted": "957846265820994568",
    "quoteGasAdjustedDecimals": "0.957846265820994568",
    "gasPriceWei": "72928221308",
    "route": [
        [
            {
                "type": "v3-pool",
                "address": "0x55CAaBB0d2b704FD0eF8192A7E35D8837e678207",
                "tokenIn": {
                    "chainId": 137,
                    "decimals": "6",
                    "address": "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
                    "symbol": "USDC"
                },
                "tokenOut": {
                    "chainId": 137,
                    "decimals": "18",
                    "address": "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619",
                    "symbol": "WETH"
                },
                "fee": "100",
                "fork": "QUICKSWAP_V3",
                "liquidity": "626108204282463914",
                "sqrtRatioX96": "1864257758031766200825822396750363",
                "tickCurrent": "201330",
                "amountIn": "1644808024",
                "amountOut": "909959204678463926"
            }
        ],
        [
            {
                "type": "v2-pool",
                "address": "0x34965ba0ac2451A34a0471F04CCa3F990b8dea27",
                "fork": "SUSHISWAP_V2",
                "tokenIn": {
                    "chainId": 137,
                    "decimals": "6",
                    "address": "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
                    "symbol": "USDC"
                },
                "tokenOut": {
                    "chainId": 137,
                    "decimals": "18",
                    "address": "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619",
                    "symbol": "ETH"
                },
                "reserve0": {
                    "token": {
                        "chainId": 137,
                        "decimals": "6",
                        "address": "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
                        "symbol": "USDC"
                    },
                    "quotient": "367169577566"
                },
                "reserve1": {
                    "token": {
                        "chainId": 137,
                        "decimals": "18",
                        "address": "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619",
                        "symbol": "ETH"
                    },
                    "quotient": "203689236636056671062"
                },
                "amountIn": "86568843",
                "amountOut": "47893191796512466"
            }
        ]
    ],
    "routeString": "[V3] 95.00% = USDC -- 0.01% [0x55CAaBB0d2b704FD0eF8192A7E35D8837e678207]-QUICKSWAP_V3 --> WETH, [V2] 5.00% = USDC -- [0x34965ba0ac2451A34a0471F04CCa3F990b8dea27]-SUSHISWAP_V2 --> ETH",
    "quoteId": "5f17d",
    "hitsCachedRoutes": true
}



const deployAndReplaceAggregator = async (_deployer: SignerWithAddress, aggregator: string) => {
    // deploy pool
    const pool = await new CometFlashAggregatorPolygon__factory(_deployer).deploy()
    console.log("get code")
    const newAggregator = await network.provider.send("eth_getCode", [
        pool.address,
    ]
    )
    await setCode(aggregator, newAggregator)
}

const user = '0xaffe73AA5EBd0CD95D89ab9fa2512Fc9e2d3289b'
const cometUSDCAddress = cometAddress[POLYGON_CHAIN_ID].USDC
const deltaProxyAddress = cometBrokerAddresses.BrokerProxy[POLYGON_CHAIN_ID]
const deltaAggregatorModuleAddress = cometBrokerAddresses.MarginTraderModule[POLYGON_CHAIN_ID]
const COMET_ID = 0

let deltaRouter: DeltaBrokerProxy
let quoter: OneDeltaQuoter
let comet: Comet
const flashInterface = FlashAggregator__factory.createInterface()
before(async function () {
    const [signer] = await ethers.getSigners();
    quoter = await new OneDeltaQuoter__factory(signer).deploy()
    console.log("deploy quoter")
    deltaRouter = await new DeltaBrokerProxy__factory(signer).attach(deltaProxyAddress)
    comet = await new Comet__factory(signer).attach(cometUSDCAddress)
    await deployAndReplaceAggregator(signer, deltaAggregatorModuleAddress)
})


it("Try Swap", async function () {
    const tokenIn = usdcAddress
    const tokenOut = wethAddress
    const amountInV2 = '86568843'
    const amountInV3 = '1644808024'
    await impersonateAccount(user)
    const impersonatedSigner = await ethers.getSigner(user);

    const pathV2 = encodeAggregatorPathEthers(
        [tokenIn, tokenOut],
        [0],
        [6], // action
        [51], // pid - V2 Sushi
        COMET_ID
    )
    const pathV3 = encodeAggregatorPathEthers(
        [tokenIn, tokenOut],
        [FeeAmount.LOW],
        [6], // action
        [1], // pid - V3
        COMET_ID
    )

    const callV2 = flashInterface.encodeFunctionData('flashSwapExactIn', [amountInV2, 0, pathV2])
    const callV3 = flashInterface.encodeFunctionData('flashSwapExactIn', [amountInV3, 0, pathV3])
    await deltaRouter.connect(impersonatedSigner).multicall(
        [
            callV3,
            callV2,
        ]
    )
})
