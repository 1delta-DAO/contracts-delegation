import { impersonateAccount } from "@nomicfoundation/hardhat-network-helpers";
import { formatEther, parseUnits } from "ethers/lib/utils";
import { AToken__factory, ConfigModule__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory, DeltaLendingInterfaceMantle, DeltaLendingInterfaceMantle__factory, ERC20Mock__factory, LensModule__factory, StableDebtToken__factory, } from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addressesLendleATokens, addressesLendleVTokens, addressesTokensMantle } from "../scripts/mantle/lendleAddresses";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { FeeAmount, MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
import { ModuleConfigAction, getSelectors } from "./libraries/diamond";
import { DeltaLendingInterfaceMantleInterface } from "../types/DeltaLendingInterfaceMantle";
const { ethers } = require("hardhat");


// block: 20240225
const MANTLE_CHAIN_ID = 5000;
const trader0 = '0xaffe73AA5EBd0CD95D89ab9fa2512Fc9e2d3289b'
const admin = '0x999999833d965c275A2C102a4Ebf222ca938546f'

const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const pendle = '0xd27B18915e7acc8FD6Ac75DB6766a80f8D2f5729'
const wbtc = "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"

const brokerProxy = lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = lendleBrokerAddresses.MarginTraderModule[MANTLE_CHAIN_ID]
const lendingModule = lendleBrokerAddresses.LendingInterface[MANTLE_CHAIN_ID]
let multicaller: DeltaBrokerProxy
let flashAggregatorInterface: DeltaFlashAggregatorMantleInterface
let lendingInterfaceInterface: DeltaLendingInterfaceMantleInterface
let user: SignerWithAddress
let trader: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer
    console.log("get aggregator")
    multicaller = await new DeltaBrokerProxy__factory(user).attach(brokerProxy)
    flashAggregatorInterface = DeltaFlashAggregatorMantle__factory.createInterface()
    lendingInterfaceInterface = DeltaLendingInterfaceMantle__factory.createInterface()

    console.log("deploy new aggregator")
    const newflashAggregator = await new DeltaFlashAggregatorMantle__factory(signer).deploy()
    console.log("deploy new lending interface")
    const newLendingInterface = await new DeltaLendingInterfaceMantle__factory(signer).deploy()

    await impersonateAccount(admin)
    const impersonatedSigner = await ethers.getSigner(admin);
    console.log(impersonatedSigner.address)

    const config = await new ConfigModule__factory(impersonatedSigner).attach(brokerProxy)
    const lens = await new LensModule__factory(impersonatedSigner).attach(brokerProxy)

    const selectors = await lens.moduleFunctionSelectors(traderModule)
    const selectorsLending = await lens.moduleFunctionSelectors(lendingModule)

    await config.configureModules([{
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: selectors
    },
    {
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: selectorsLending
    },
    {
        moduleAddress: newflashAggregator.address,
        action: ModuleConfigAction.Add,
        functionSelectors: getSelectors(newflashAggregator)
    },
    {
        moduleAddress: newLendingInterface.address,
        action: ModuleConfigAction.Add,
        functionSelectors: getSelectors(newLendingInterface)
    }])


})

it("WMNT->PENDLE exactIn (velo_vola)", async function () {
    const amount = parseUnits('0.0789358', 18)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [pendle])
    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    // const unwrap = lendingInterfaceInterface.encodeFunctionData('unwrap',)
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)
    const tokenPendle = await new ERC20Mock__factory(user).attach(pendle)
    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, pendle],
        [0],
        [1],
        [52], // celo, velo v
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactInSpot', [amount, 0, path1])
    console.log("attempt swap")

    const balPre = await tokenPendle.balanceOf(trader0)

    await multicaller.connect(impersonatedSigner).multicall([
        wrap,
        callSwap,
        sweep,
        // unwrap
    ],
        { value: parseUnits('1', 18) })

    const balAfter = await tokenPendle.balanceOf(trader0)
    console.log("receive", formatEther(balAfter.sub(balPre)))
    const data = '0xac9650d800000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000004d46eb1190000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c40bfa0b88000000000000000000000000000000000000000000000000006a94d74f43000000000000000000000000000000000000000000000000000001186fbd045b21b10000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000002ed27b18915e7acc8fd6ac75db6766a80f8d2f5729000000350178c1b0c915c4faa5fffa6cabf0219da63d7f4cb86300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002401681a62000000000000000000000000d27b18915e7acc8fd6ac75db6766a80f8d2f5729000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004fd02ffb700000000000000000000000000000000000000000000000000000000'
})


it("WMNT->PENDLE exactOut (velo_vola)", async function () {
    const amount = parseUnits('0.03', 18)
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [pendle])
    const wrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const unwrap = lendingInterfaceInterface.encodeFunctionData('unwrap',)
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)

    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [wmnt, pendle].reverse(),
        [0].reverse(),
        [1],
        [52].reverse(), // celo, velo v
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amount, MaxUint128, path1])
    console.log("attempt swap")


    await multicaller.connect(impersonatedSigner).multicall([
        wrap,
        callSwap,
        sweep,
        unwrap
    ],
        { value: parseUnits('1', 18) })
    const data = '0xac9650d800000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000004d46eb1190000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c40bfa0b88000000000000000000000000000000000000000000000000006a94d74f43000000000000000000000000000000000000000000000000000001186fbd045b21b10000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000002ed27b18915e7acc8fd6ac75db6766a80f8d2f5729000000350178c1b0c915c4faa5fffa6cabf0219da63d7f4cb86300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002401681a62000000000000000000000000d27b18915e7acc8fd6ac75db6766a80f8d2f5729000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004fd02ffb700000000000000000000000000000000000000000000000000000000'
})


it("USDC->WMNT->PENDLE exactOut (velo_stable)", async function () {
    const amount = '112741000000000000'
    const sweep = lendingInterfaceInterface.encodeFunctionData('sweep', [usdc])
    await impersonateAccount(trader0)
    const impersonatedSigner = await ethers.getSigner(trader0);
    console.log(impersonatedSigner.address)

    // v3 single
    const path1 = encodeAggregatorPathEthers(
        [usdc, wmnt, pendle].reverse(),
        [250, 0].reverse(),
        [1, 1],
        [4, 52].reverse(), // celo, velo v
        99
    )
    const callSwap = flashAggregatorInterface.encodeFunctionData('swapExactOutSpot', [amount, MaxUint128, path1])
    console.log("attempt swap")


    await multicaller.connect(impersonatedSigner).multicall([
        // transferIn,
        callSwap,
        sweep
    ])
    const data = '0xac9650d800000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000004d46eb1190000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c40bfa0b88000000000000000000000000000000000000000000000000006a94d74f43000000000000000000000000000000000000000000000000000001186fbd045b21b10000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000002ed27b18915e7acc8fd6ac75db6766a80f8d2f5729000000350178c1b0c915c4faa5fffa6cabf0219da63d7f4cb86300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002401681a62000000000000000000000000d27b18915e7acc8fd6ac75db6766a80f8d2f5729000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004fd02ffb700000000000000000000000000000000000000000000000000000000'
})



const xx = {
    "blockNumber": "49004002",
    "amount": "112741000000000000",
    "amountDecimals": "0.112741",
    "quote": "200005",
    "quoteDecimals": "0.200005",
    "quoteGasAdjusted": "200022",
    "quoteGasAdjustedDecimals": "0.200022",
    "gasPriceWei": "50000000",
    "route": [
        [
            {
                "type": "v3-pool",
                "address": "0xCd07Bcf06F3Ad0EaC869BDec3E9065864A348875",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                    "symbol": "USDC"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "fee": "250",
                "fork": "CLEOPATRA",
                "liquidity": "17554280048865435340",
                "sqrtRatioX96": "96469737248093005733359904002429570",
                "tickCurrent": "280262",
                "amountIn": "150232"
            },
            {
                "type": "v2-pool",
                "address": "0x65F0371e1e67d1e2413058B67b051924de98AEdf",
                "fork": "VELOCIMETER_VOLATILE",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0xd27B18915e7acc8FD6Ac75DB6766a80f8D2f5729",
                    "symbol": "PENDLE"
                },
                "reserve0": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                        "symbol": "WMNT"
                    },
                    "quotient": "213258214233226084207"
                },
                "reserve1": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0xd27B18915e7acc8FD6Ac75DB6766a80f8D2f5729",
                        "symbol": "PENDLE"
                    },
                    "quotient": "81283078170458526893"
                },
                "amountOut": "84555750000000000"
            }
        ],
        [
            {
                "type": "v3-pool",
                "address": "0xC0b66C7535423395Fc53eB4cb0CE9bcA1621DaE6",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                    "symbol": "USDC"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
                    "symbol": "WETH"
                },
                "fee": "500",
                "fork": "CLEOPATRA",
                "liquidity": "535204670528832265",
                "sqrtRatioX96": "1594681077008357489007820839763873",
                "tickCurrent": "198206",
                "amountIn": "49773"
            },
            {
                "type": "v3-pool",
                "address": "0x54169896d28dec0FFABE3B16f90f71323774949f",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
                    "symbol": "WETH"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "fee": "500",
                "fork": "AGNI",
                "liquidity": "220001209606181609447648",
                "sqrtRatioX96": "1309757993278012247848722382",
                "tickCurrent": "-82054"
            },
            {
                "type": "v2-pool",
                "address": "0x9698f1ab4b391D090ea38cFdCa6802a20FF19642",
                "fork": "FUSIONX_V2",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0xd27B18915e7acc8FD6Ac75DB6766a80f8D2f5729",
                    "symbol": "PENDLE"
                },
                "reserve0": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                        "symbol": "WMNT"
                    },
                    "quotient": "9038910780835497403"
                },
                "reserve1": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0xd27B18915e7acc8FD6Ac75DB6766a80f8D2f5729",
                        "symbol": "PENDLE"
                    },
                    "quotient": "3492043964315044128"
                },
                "amountOut": "28185250000000000"
            }
        ]
    ],
    "routeString": "[V2 + V3] 75.00% = USDC -- 0.025% [0xCd07Bcf06F3Ad0EaC869BDec3E9065864A348875]-CLEOPATRA --> WMNT -- [0x65F0371e1e67d1e2413058B67b051924de98AEdf]-VELOCIMETER_VOLATILE --> PENDLE, [V2 + V3] 25.00% = USDC -- 0.05% [0xC0b66C7535423395Fc53eB4cb0CE9bcA1621DaE6]-CLEOPATRA --> WETH -- 0.05% [0x54169896d28dec0FFABE3B16f90f71323774949f]-AGNI --> WMNT -- [0x9698f1ab4b391D090ea38cFdCa6802a20FF19642]-FUSIONX_V2 --> PENDLE",
    "quoteId": "d645c",
    "hitsCachedRoutes": true
}

const xx2 = {
    "blockNumber": "49004862",
    "amount": "1000000000000000000",
    "amountDecimals": "1",
    "quote": "680191",
    "quoteDecimals": "0.680191",
    "quoteGasAdjusted": "680180",
    "quoteGasAdjustedDecimals": "0.68018",
    "gasPriceWei": "50000000",
    "route": [
        [
            {
                "type": "v2-pool",
                "address": "0xcA455F94225A447c677ef0BF3a0c05626c090cD1",
                "fork": "VELOCIMETER_VOLATILE",
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
                    "quotient": "1051191359"
                },
                "reserve1": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                        "symbol": "WMNT"
                    },
                    "quotient": "1550819446514535326721"
                },
                "amountIn": "850000000000000000",
                "amountOut": "574400"
            }
        ],
        [
            {
                "type": "v2-pool",
                "address": "0xF99ef8dF4F8B62f6031cFc6a36388CE7DA48e4b8",
                "fork": "VELOCIMETER_VOLATILE",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "6",
                    "address": "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE",
                    "symbol": "USDT"
                },
                "reserve0": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "6",
                        "address": "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE",
                        "symbol": "USDT"
                    },
                    "quotient": "6382043360"
                },
                "reserve1": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                        "symbol": "WMNT"
                    },
                    "quotient": "9424169822586945066084"
                },
                "amountIn": "150000000000000000"
            },
            {
                "type": "v2-pool",
                "address": "0x42473110452eE65455C093544A12B68ac7c542B2",
                "fork": "VELOCIMETER_VOLATILE",
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
                "reserve0": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "6",
                        "address": "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9",
                        "symbol": "USDC"
                    },
                    "quotient": "2099750"
                },
                "reserve1": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "6",
                        "address": "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE",
                        "symbol": "USDT"
                    },
                    "quotient": "1904989"
                },
                "amountOut": "105791"
            }
        ]
    ],
    "routeString": "[V2] 85.00% = WMNT -- [0xcA455F94225A447c677ef0BF3a0c05626c090cD1]-VELOCIMETER_VOLATILE --> USDC, [V2] 15.00% = WMNT -- [0xF99ef8dF4F8B62f6031cFc6a36388CE7DA48e4b8]-VELOCIMETER_VOLATILE --> USDT -- [0x42473110452eE65455C093544A12B68ac7c542B2]-VELOCIMETER_VOLATILE --> USDC",
    "quoteId": "96b2b",
    "hitsCachedRoutes": true
}