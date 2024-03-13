import { impersonateAccount, mine, setCode } from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits } from "ethers/lib/utils";
import { ConfigModule__factory, DeltaBrokerProxy, DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory, DeltaLendingInterfaceMantle__factory, LensModule__factory } from "../types";
import { lendleBrokerAddresses } from "../deploy/mantle_addresses";
import { DeltaFlashAggregatorMantleInterface } from "../types/DeltaFlashAggregatorMantle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addressesTokensMantle } from "../scripts/mantle/lendleAddresses";
import { network } from "hardhat";
import { DeltaLendingInterfaceMantleInterface } from "../types/DeltaLendingInterfaceMantle";
import { ModuleConfigAction, getSelectors } from "./libraries/diamond";
import { encodeAggregatorPathEthers } from "./1delta/shared/aggregatorPath";
import { MaxUint128 } from "./uniswap-v3/periphery/shared/constants";
const { ethers } = require("hardhat");

const MANTLE_CHAIN_ID = 5000;
const admin = '0x999999833d965c275A2C102a4Ebf222ca938546f'
const traderAddress = '0xcccccda06B44bcc94618620297Dc252EcfB56d85'


const weth = "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111"
const wbtc = "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2"
const usdc = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"
const wmnt = "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8"
const usdt = "0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE"


const brokerProxy = lendleBrokerAddresses.BrokerProxy[MANTLE_CHAIN_ID]
const traderModule = lendleBrokerAddresses.MarginTraderModule[MANTLE_CHAIN_ID]
const lenderModule = lendleBrokerAddresses.LendingInterface[MANTLE_CHAIN_ID]

let multicaller: DeltaBrokerProxy
let flashAggregatorInterface: DeltaFlashAggregatorMantleInterface
let lendingInterfaceInterface: DeltaLendingInterfaceMantleInterface
let user: SignerWithAddress
let trader: SignerWithAddress
before(async function () {
    const [signer] = await ethers.getSigners();
    user = signer

    await impersonateAccount(traderAddress)
    trader = await ethers.getSigner(traderAddress);
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
    const selectorsLender = await lens.moduleFunctionSelectors(lenderModule)
    await config.configureModules([{
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: selectors
    },
    {
        moduleAddress: ethers.constants.AddressZero,
        action: ModuleConfigAction.Remove,
        functionSelectors: selectorsLender
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
    }
    ])


})


it("Test repay", async function () {
    const amount = parseUnits('1.0', 18)
    const callWrap = lendingInterfaceInterface.encodeFunctionData('wrap',)
    const callUnwrap = lendingInterfaceInterface.encodeFunctionData('unwrap',)
    const callRepay = lendingInterfaceInterface.encodeFunctionData('repay', [wbtc, trader.address, 2, 0])

    const path0 = encodeAggregatorPathEthers(
        [wbtc, wmnt],
        [2500],
        [1],
        [0], // fusion 3
        99
    )
    const path1 = encodeAggregatorPathEthers(
        [wbtc, wmnt],
        [0],
        [1],
        [50], // fusion 2
        99
    )
    const path2 = encodeAggregatorPathEthers(
        [wbtc, wmnt],
        [0],
        [1],
        [51], // moe
        99
    )
    const amount0 = '1238'
    // const amount1 = '309'
    const value ='988552721525158395'// '988552721525158395'
    // const amount2 = '99018003124066296'
    const swap0 = flashAggregatorInterface.encodeFunctionData('swapExactOutSpotSelf', [amount0, MaxUint128, path0])
    const swap1 = flashAggregatorInterface.encodeFunctionData('swapAllOutSpotSelf', [MaxUint128, 0, '2', path1])
    // const swap2 = flashAggregatorInterface.encodeFunctionData('swapAllOutSpotSelf', [MaxUint128, '2', path2])
   const calls = [
        callWrap,
        swap0,
        // swap1,
        callRepay,
        swap1,
        callRepay,
        callUnwrap
    ]
    
    await multicaller.connect(trader).multicall(
        calls
        , { value }
    )
})



const repay_wbtc_eo = {
    "blockNumber": "50109579",
    "amount": "1548",
    "amountDecimals": "0.00001548",
    "quote": "985595933723986436",
    "quoteDecimals": "0.985595933723986436",
    "quoteGasAdjusted": "985614283723986436",
    "quoteGasAdjustedDecimals": "0.985614283723986436",
    "gasPriceWei": "50000000",
    "route": [
        [
            {
                "type": "v3-pool",
                "address": "0xfA0D6714eEaeccCADe0558286398D326A2b9DbbE",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "8",
                    "address": "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2",
                    "symbol": "WBTC"
                },
                "fee": "2500",
                "fork": "FUSIONX_V3",
                "liquidity": "10123669546140",
                "sqrtRatioX96": "3144287887815117241495",
                "tickCurrent": "-340863",
                "amountIn": "691197817897968374",
                "amountOut": "1083"
            }
        ],
        [
            {
                "type": "v2-pool",
                "address": "0xc69a23ba0cE530de100D96eD16f3614Fbf8610bf",
                "fork": "FUSIONX_V2",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "8",
                    "address": "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2",
                    "symbol": "WBTC"
                },
                "reserve0": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                        "symbol": "WMNT"
                    },
                    "quotient": "15358093399916575584"
                },
                "reserve1": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "8",
                        "address": "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2",
                        "symbol": "WBTC"
                    },
                    "quotient": "24647"
                },
                "amountIn": "195380112701951766",
                "amountOut": "309"
            }
        ],
        [
            {
                "type": "v2-pool",
                "address": "0xB1e695DC6cA41D0Dc5030d7e316c879a47FD492a",
                "fork": "MERCHANT_MOE",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "8",
                    "address": "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2",
                    "symbol": "WBTC"
                },
                "reserve0": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                        "symbol": "WMNT"
                    },
                    "quotient": "9941756003017432899863"
                },
                "reserve1": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "8",
                        "address": "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2",
                        "symbol": "WBTC"
                    },
                    "quotient": "15508822"
                },
                "amountIn": "99018003124066296",
                "amountOut": "154"
            }
        ]
    ],
    "routeString": "[V3] 70.00% = WMNT -- 0.25% [0xfA0D6714eEaeccCADe0558286398D326A2b9DbbE]-FUSIONX_V3 --> WBTC, [V2] 20.00% = WMNT -- [0xc69a23ba0cE530de100D96eD16f3614Fbf8610bf]-FUSIONX_V2 --> WBTC, [V2] 10.00% = WMNT -- [0xB1e695DC6cA41D0Dc5030d7e316c879a47FD492a]-MERCHANT_MOE --> WBTC",
    "quoteId": "321b5",
    "hitsCachedRoutes": true
}

const trade2 = {
    "blockNumber": "50128627",
    "amount": "1548",
    "amountDecimals": "0.00001548",
    "quote": "985808589692444414",
    "quoteDecimals": "0.985808589692444414",
    "quoteGasAdjusted": "985820189692444414",
    "quoteGasAdjustedDecimals": "0.985820189692444414",
    "gasPriceWei": "50000000",
    "route": [
        [
            {
                "type": "v3-pool",
                "address": "0xfA0D6714eEaeccCADe0558286398D326A2b9DbbE",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "8",
                    "address": "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2",
                    "symbol": "WBTC"
                },
                "fee": "2500",
                "fork": "FUSIONX_V3",
                "liquidity": "10123669546140",
                "sqrtRatioX96": "3144287887815117241495",
                "tickCurrent": "-340863",
                "amountIn": "790428476990492648",
                "amountOut": "1238"
            }
        ],
        [
            {
                "type": "v2-pool",
                "address": "0xc69a23ba0cE530de100D96eD16f3614Fbf8610bf",
                "fork": "FUSIONX_V2",
                "tokenIn": {
                    "chainId": 5000,
                    "decimals": "18",
                    "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                    "symbol": "WMNT"
                },
                "tokenOut": {
                    "chainId": 5000,
                    "decimals": "8",
                    "address": "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2",
                    "symbol": "WBTC"
                },
                "reserve0": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "18",
                        "address": "0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8",
                        "symbol": "WMNT"
                    },
                    "quotient": "15358093399916575584"
                },
                "reserve1": {
                    "token": {
                        "chainId": 5000,
                        "decimals": "8",
                        "address": "0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2",
                        "symbol": "WBTC"
                    },
                    "quotient": "24647"
                },
                "amountIn": "195380112701951766",
                "amountOut": "309"
            }
        ]
    ],
    "routeString": "[V3] 80.00% = WMNT -- 0.25% [0xfA0D6714eEaeccCADe0558286398D326A2b9DbbE]-FUSIONX_V3 --> WBTC, [V2] 20.00% = WMNT -- [0xc69a23ba0cE530de100D96eD16f3614Fbf8610bf]-FUSIONX_V2 --> WBTC",
    "quoteId": "ed4d0",
    "hitsCachedRoutes": true
}