import { impersonateAccount, mine, setCode } from "@nomicfoundation/hardhat-network-helpers";
import {
    DeltaBrokerProxy,
    DeltaBrokerProxy__factory,
    DeltaFlashAggregatorMantle,
    DeltaFlashAggregatorMantle__factory,
    DeltaLendingInterfaceMantle__factory,
    ERC20Mock__factory
} from "../types";
import { ONE_DELTA_ADDRESSES } from "../deploy/mantle_addresses";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { network } from "hardhat";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { BigNumber } from "ethers";
const { ethers } = require("hardhat");

// block: 
const MANTLE_CHAIN_ID = 5000;
const trader0 = '0x5c382c7c80BE53edaA982378540B8797667859F7'

const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"
const moe = "0x4515A45337F461A11Ff0FE8aBF3c606AE5dC00c9"
const usdy = '0x5be26527e817998a7206475496fde1e68957c5a6'

let multicaller: DeltaBrokerProxy
let flashAggregator: DeltaFlashAggregatorMantle
const flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
const moneyMarketInterface = DeltaLendingInterfaceMantle__factory.createInterface()
let user: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(user).attach(ONE_DELTA_ADDRESSES.BrokerProxy[MANTLE_CHAIN_ID])
    flashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).attach(multicaller.address)
    console.log("deploy new aggregator")
    const newflashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).deploy()

    const traderModule = ONE_DELTA_ADDRESSES.MarginTraderModule[MANTLE_CHAIN_ID]
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

const adjustForSlippage = (s: string, slippageBp: number) => BigNumber.from(s).mul(10000 - slippageBp).div(10000)


it("Test Moe Swap", async function () {
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);

    const slippage = 30

    const amountIn2 = '2000000'
    const transferIn = moneyMarketInterface.encodeFunctionData('transferERC20In', [usdt, amountIn2])
    const USDTContract = await new ERC20Mock__factory(impersonatedSigner).attach(usdt)
    const bal = await USDTContract.balanceOf(trader0)
    await USDTContract.approve(multicaller.address, amountIn2)
    console.log("bal", bal.toString())

    // v3 single
    const path2 = encodeAggregatorPathEthers(
        [usdt, moe],
        [0],
        [0],
        [51], // moe
        99
    )
    const swap2 = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amountIn2, 0, path2])

    const sweep = moneyMarketInterface.encodeFunctionData('sweep', [moe])

    await multicaller.connect(impersonatedSigner).multicall([
        transferIn,
        swap2,
        sweep
    ])
})


it.skip("Test Swap", async function () {
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);

    const slippage = 30


    const transferIn = moneyMarketInterface.encodeFunctionData('transferERC20In', [usdt, '10000000'])
    // v3 multi
    const path1 = encodeAggregatorPathEthers(
        [usdt, weth, usdc, usdy],
        [500, 500, 100],
        [0, 0, 0],
        [1, 0, 1,],
        99
    )

    const amountIn1 = "9500000"
    const amountOutMin1 = adjustForSlippage("9317149848124203864", slippage)
    const swap1 = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amountIn1, amountOutMin1, path1])

    // v3 single
    const path2 = encodeAggregatorPathEthers(
        [usdt, usdy],
        [100],
        [0],
        [1],
        99
    )
    const amountIn2 = "500000"
    const amountOutMin2 = adjustForSlippage("490388027145743534", slippage)
    const swap2 = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amountIn2, amountOutMin2, path2])

    const sweep = moneyMarketInterface.encodeFunctionData('sweep', [usdy,])

    await multicaller.connect(impersonatedSigner).multicall([
        transferIn,
        swap1,
        swap2,
        sweep
    ])
})

const trade = {
    "blockNumber": "29148766",
    "amount": "10000000",
    "amountDecimals": "10",
    "quote": "9807537875269947398",
    "quoteDecimals": "9.807537875269947398",
    "quoteGasAdjusted": "9807528362676948768",
    "quoteGasAdjustedDecimals": "9.807528362676948768",
    "gasPriceWei": "50000000",
    "route": [
        [
            {
                "type": "v3-pool",
                "address": "0x628f7131CF43e88EBe3921Ae78C4bA0C31872bd4",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE",
                    "symbol": "USDT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
                    "symbol": "WETH"
                },
                "fee": "500",
                "fork": "AGNI",
                "liquidity": "124160434475802852",
                "sqrtRatioX96": "1682568560326861397595343008989716",
                "tickCurrent": "199279",
                "amountIn": "9500000"
            },
            {
                "type": "v3-pool",
                "address": "0x01845ec86909006758DE0D57957D88Da10bf5809",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
                    "symbol": "WETH"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                    "symbol": "USDC"
                },
                "fee": "500",
                "fork": "FUSIONX_V3",
                "liquidity": "200348221583405175",
                "sqrtRatioX96": "1682945365715060423897439386084654",
                "tickCurrent": "199284"
            },
            {
                "type": "v3-pool",
                "address": "0x9cd55b03c64B65Ba02A1D985Caef63046B2d54eb",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                    "symbol": "USDC"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x5be26527e817998a7206475496fde1e68957c5a6",
                    "symbol": "USDY"
                },
                "fee": "100",
                "fork": "AGNI",
                "liquidity": "4469954010547233563111",
                "sqrtRatioX96": "78474704464222346438090379069881528",
                "tickCurrent": "276132",
                "amountOut": "9317149848124203864"
            }
        ],
        [
            {
                "type": "v3-pool",
                "address": "0xe38E3a804eF845e36F277D86Fb2b24b8C32B3340",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE",
                    "symbol": "USDT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x5be26527e817998a7206475496fde1e68957c5a6",
                    "symbol": "USDY"
                },
                "fee": "100",
                "fork": "AGNI",
                "liquidity": "926194519042336",
                "sqrtRatioX96": "78487828545792232372306203143581946",
                "tickCurrent": "276136",
                "amountIn": "500000",
                "amountOut": "490388027145743534"
            }
        ]
    ],
    "routeString": "[V3] 95.00% = USDT -- 0.05% [0x628f7131CF43e88EBe3921Ae78C4bA0C31872bd4]-AGNI --> WETH -- 0.05% [0x01845ec86909006758DE0D57957D88Da10bf5809]-FUSIONX_V3 --> USDC -- 0.01% [0x9cd55b03c64B65Ba02A1D985Caef63046B2d54eb]-AGNI --> USDY, [V3] 5.00% = USDT -- 0.01% [0xe38E3a804eF845e36F277D86Fb2b24b8C32B3340]-AGNI --> USDY",
    "quoteId": "37b23",
    "hitsCachedRoutes": true
}