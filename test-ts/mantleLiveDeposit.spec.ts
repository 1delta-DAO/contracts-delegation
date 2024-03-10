import { impersonateAccount, mine, setCode } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import { DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory, DeltaLendingInterfaceMantle__factory } from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addressesTokensMantle } from "../scripts/mantle/lendleAddresses";
import { network } from "hardhat";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount } from "./uniswap-v3/periphery/shared/constants";
import { BigNumber } from "ethers";
const { ethers } = require("hardhat");

const MANTLE_CHAIN_ID = 5000;
const trader0 = '0xaffe73AA5EBd0CD95D89ab9fa2512Fc9e2d3289b'
const admin = ''

const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"

const adjustForSlippage = (s: string, slippageBp: number) => BigNumber.from(s).mul(10000 + slippageBp).div(10000)

let multicaller: DeltaBrokerProxy
let flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
let lendingInterfaceInterface = DeltaLendingInterfaceMantle__factory.createInterface()
let user: SignerWithAddress
let trader: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(user).attach(lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID])

    console.log("deploy new aggregator")
    const newflashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).deploy()
    await impersonateAccount(admin)
    const impersonatedSigner = await ethers.getSigner(admin);
    console.log(impersonatedSigner.address)

    const traderModule = lendleBrokerAddresses.MarginTraderModule[MANTLE_CHAIN_ID]
    console.log("get code")
    const newflashAggregatorCode = await network.provider.send("eth_getCode", [
        newflashAggregator.address,
    ]
    )
    console.log("set code")
    // set the code
    await setCode(traderModule, newflashAggregatorCode)
    await mine(2)

})


it("Test deposit", async function () {
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);

    const amount = parseUnits('10.0', 18)
    const tokenIn = addressesTokensMantle.WMNT
    const callWrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const callDeposit = flashAggregatorInterface.encodeFunctionData('deposit' as any, [tokenIn, user.address])

    // same slippage for all swaps
    const slippage = 30

    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, wmnt],
        [FeeAmount.LOW],
        [1],
        [0],
        99
    )
    const amountOut1 = "800000"
    const amountInMax1 = adjustForSlippage("1795534517803517894", slippage)
    const swap1 = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amountOut1, amountInMax1, path1])

    // v3 multi
    const path2 = encodeAggregatorPathEthers(
        [usdc, usdt, weth, wmnt],
        [100, 500, 500],
        [1, 1, 1,],
        [0, 0, 0],
        99
    )
    const amountOut2 = "800000"
    const amountInMax2 = adjustForSlippage("1791789106957625607", slippage)
    const swap2 = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amountOut2, amountInMax2, path2])

    // v3 single
    const path3 = encodeAggregatorPathEthers(
        [usdc, wmnt],
        [2500],
        [1],
        [0],
        99
    )
    const amountOut3 = "300000"
    const amountInMax3 = adjustForSlippage("673373817748534812", slippage)
    const swap3 = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amountOut3, amountInMax3, path3])

    // v2 + v3 multi
    const path4 = encodeAggregatorPathEthers(
        [usdc, wmnt, usdt, wmnt],
        [0, 500, 2500],
        [1, 1, 1,],
        [50, 0, 0],
        99
    )
    const amountOut4 = "100000"
    const amountInMax4 = adjustForSlippage("224601079456675981", slippage)
    const swap4 = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amountOut4, amountInMax4, path4])


    await multicaller.connect(impersonatedSigner).multicall([
        callWrap,
        swap1,
        swap2,
        swap3,
        swap4,
        callDeposit
    ], { value: amount })

})


const routeData = {
    "blockNumber": "20240225",
    "amount": "2000000",
    "amountDecimals": "2",
    "quote": "4485298521966354294",
    "quoteDecimals": "4.485298521966354294",
    "quoteGasAdjusted": "4485335171966354294",
    "quoteGasAdjustedDecimals": "4.485335171966354294",
    "gasPriceWei": "50000000",
    "route": [
        [
            {
                "type": "v3-pool",
                "address": "0xe87E42ff34d6baAF619eB91dd957e4EC45226894",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "W"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                    "symbol": "USDC"
                },
                "fee": "500",
                "fork": "FUSIONX_V3",
                "liquidity": "4195458387078338",
                "sqrtRatioX96": "118637968297442114748009673195167033",
                "tickCurrent": "284399",
                "amountIn": "1795534517803517894",
                "amountOut": "800000"
            }
        ],
        [
            {
                "type": "v3-pool",
                "address": "0x47453Cb250f705211e7a0De2f9c5D94CfeCc8ABD",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "W"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
                    "symbol": "WETH"
                },
                "fee": "500",
                "fork": "FUSIONX_V3",
                "liquidity": "20755332191295022805",
                "sqrtRatioX96": "1212887819396022963123602972",
                "tickCurrent": "-83591",
                "amountIn": "1791789106957625607"
            },
            {
                "type": "v3-pool",
                "address": "0xA125AF1A4704044501Fe12Ca9567eF1550E430e8",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
                    "symbol": "WETH"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE",
                    "symbol": "USDT"
                },
                "fee": "500",
                "fork": "FUSIONX_V3",
                "liquidity": "54446805652390683",
                "sqrtRatioX96": "1812939175259246682905412716636384",
                "tickCurrent": "200772"
            },
            {
                "type": "v3-pool",
                "address": "0x16867D00D45347A2DeD25B8cdB7022b3171D4ae0",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE",
                    "symbol": "USDT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                    "symbol": "USDC"
                },
                "fee": "100",
                "fork": "FUSIONX_V3",
                "liquidity": "619845663312622",
                "sqrtRatioX96": "79239292559411525302422372691",
                "tickCurrent": "2",
                "amountOut": "800000"
            }
        ],
        [
            {
                "type": "v3-pool",
                "address": "0xAAecd138ad9Cd20C13f1593a41bF3941940eC41e",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "W"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                    "symbol": "USDC"
                },
                "fee": "2500",
                "fork": "FUSIONX_V3",
                "liquidity": "639099773696141",
                "sqrtRatioX96": "118508909046752478436594445995179967",
                "tickCurrent": "284377",
                "amountIn": "673373817748534812",
                "amountOut": "300000"
            }
        ],
        [
            {
                "type": "v3-pool",
                "address": "0xeD3ee32bDcF51632707f130af827FD849929570e",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "W"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE",
                    "symbol": "USDT"
                },
                "fee": "2500",
                "fork": "FUSIONX_V3",
                "liquidity": "2239781163243357",
                "sqrtRatioX96": "118538738039384245395342311259594559",
                "tickCurrent": "284382",
                "amountIn": "224601079456675981"
            },
            {
                "type": "v3-pool",
                "address": "0x262255F4770aEbE2D0C8b97a46287dCeCc2a0AfF",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE",
                    "symbol": "USDT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "fee": "500",
                "fork": "FUSIONX_V3",
                "liquidity": "3477981298732299487",
                "sqrtRatioX96": "118637440542134147957928267887593846",
                "tickCurrent": "284399"
            },
            {
                "type": "v2-pool",
                "address": "0xf9CdA48949AE1823eEcdd314DeEcD8599Ceaf7cc",
                "fork": "FUSIONX_V2",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                    "symbol": "USDC"
                },
                "reserve0": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "6",
                        "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                        "symbol": "USDC"
                    },
                    "quotient": "756605975"
                },
                "reserve1": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                        "symbol": "W"
                    },
                    "quotient": "1693323349464485487017"
                },
                "amountOut": "100000"
            }
        ]
    ],
    "routeString": "[V3] 40.00% = W -- 0.05% [0xe87E42ff34d6baAF619eB91dd957e4EC45226894]-FUSIONX_V3 --> USDC, [V3] 40.00% = W -- 0.05% [0x47453Cb250f705211e7a0De2f9c5D94CfeCc8ABD]-FUSIONX_V3 --> WETH -- 0.05% [0xA125AF1A4704044501Fe12Ca9567eF1550E430e8]-FUSIONX_V3 --> USDT -- 0.01% [0x16867D00D45347A2DeD25B8cdB7022b3171D4ae0]-FUSIONX_V3 --> USDC, [V3] 15.00% = W -- 0.25% [0xAAecd138ad9Cd20C13f1593a41bF3941940eC41e]-FUSIONX_V3 --> USDC, [V2 + V3] 5.00% = W -- 0.25% [0xeD3ee32bDcF51632707f130af827FD849929570e]-FUSIONX_V3 --> USDT -- 0.05% [0x262255F4770aEbE2D0C8b97a46287dCeCc2a0AfF]-FUSIONX_V3 --> WMNT -- [0xf9CdA48949AE1823eEcdd314DeEcD8599Ceaf7cc]-FUSIONX_V2 --> USDC",
    "quoteId": "bcbbf",
    "hitsCachedRoutes": true
}