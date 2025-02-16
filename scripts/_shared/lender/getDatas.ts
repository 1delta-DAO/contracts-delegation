
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"
import { AAVE_FORK_POOL_DATA, AAVE_STYLE_RESERVE_ASSETS, AAVE_STYLE_TOKENS, Chain, COMETS_PER_CHAIN_MAP, COMPOUND_STYLE_RESERVE_ASSETS, Lender } from "@1delta/asset-registry"

export enum ArbitrumLenderId {
    // aave v3s
    AAVE_V3 = 0,
    AVALON = 100,
    AVALON_PBTC = 101,
    YLDR = 900,
    // comets
    COMPOUND_V3_USDC = 2000,
    COMPOUND_V3_WETH = 2001,
    COMPOUND_V3_USDT = 2002,
    COMPOUND_V3_USDCE = 2003,
    // venuses
    VENUS = 3000,
    VENUS_ETH = 3001,
}

export enum BaseLenderId {
    // aave v3s
    AAVE_V3 = 0,
    AVALON = 100,
    ZEROLEND = 210,
    // comets
    COMPOUND_V3_USDC = 2000,
    COMPOUND_V3_WETH = 2001,
    COMPOUND_V3_USDBC = 2002,
    COMPOUND_V3_AERO = 2003,
    // venuses
    VENUS = 3000,
}

export enum OptimismLenderId {
    // aave v3s
    AAVE_V3 = 0,
    // comets
    COMPOUND_V3_USDT = 2000,
    COMPOUND_V3_USDC = 2001,
    COMPOUND_V3_WETH = 2002,
    // venuses
    VENUS = 3000,
}

export enum EthereumLenderId {
    // aave v3s
    AAVE_V3 = 0,
    AAVE_V3_PRIME = 1,
    AAVE_V3_ETHER_FI = 2,
    SPARK = 200,
    KINZA = 250,
    // avalons
    AVALON_SOLV_BTC = 100,
    AVALON_SWELL_BTC = 101,
    AVALON_PUMP_BTC = 102,
    AVALON_EBTC_LBTC = 103,

    // zerolends
    ZEROLEND_STABLECOINS_RWA = 210,
    ZEROLEND_ETH_LRTS = 211,
    ZEROLEND_BTC_LRTS = 212,
    // comets
    COMPOUND_V3_USDC = 2000,
    COMPOUND_V3_WETH = 2001,
    COMPOUND_V3_USDT = 2002,
    COMPOUND_V3_WSTETH = 2003,
    COMPOUND_V3_USDS = 2004,
    // venuses
    VENUS = 3000,
}

export enum TaikoLenderId {
    HANA = 0,
    AVALON = 100,
    AVALON_SOLV_BTC = 101,
    AVALON_USDA = 150,
    MERIDIAN = 1000,
    TAKOTAKO = 1001
}

export enum MantleLenderId {
    KINZA = 250,
    LENDLE = 1000,
    AURELIUS = 1001,
    COMPOUND_V3_USDE = 2000
}

export const LENDER_TO_ID: { [c: string | number]: { [k: string]: any } } = {
    [Chain.ARBITRUM_ONE]: {
        [Lender.AAVE_V3]: ArbitrumLenderId.AAVE_V3,
        [Lender.AVALON]: ArbitrumLenderId.AVALON,
        [Lender.AVALON_PUMP_BTC]: ArbitrumLenderId.AVALON_PBTC,
        [Lender.YLDR]: ArbitrumLenderId.YLDR,
        // comets
        [Lender.COMPOUND_V3_USDC]: ArbitrumLenderId.COMPOUND_V3_USDC,
        [Lender.COMPOUND_V3_WETH]: ArbitrumLenderId.COMPOUND_V3_WETH,
        [Lender.COMPOUND_V3_USDT]: ArbitrumLenderId.COMPOUND_V3_USDT,
        [Lender.COMPOUND_V3_USDC_E]: ArbitrumLenderId.COMPOUND_V3_USDCE,
        // venuses
        [Lender.VENUS]: ArbitrumLenderId.VENUS,
        // [Lender.VENUS_ETH]: ArbitrumLenderId.VENUS_ETH,
    },
    [Chain.BASE]: {
        [Lender.AAVE_V3]: BaseLenderId.AAVE_V3,
        [Lender.AVALON]: BaseLenderId.AVALON,
        [Lender.ZEROLEND]: BaseLenderId.ZEROLEND,
        // comets
        [Lender.COMPOUND_V3_USDC]: BaseLenderId.COMPOUND_V3_USDC,
        [Lender.COMPOUND_V3_WETH]: BaseLenderId.COMPOUND_V3_WETH,
        [Lender.COMPOUND_V3_USDBC]: BaseLenderId.COMPOUND_V3_USDBC,
        [Lender.COMPOUND_V3_AERO]: BaseLenderId.COMPOUND_V3_AERO,
        // venuses
        [Lender.VENUS]: BaseLenderId.VENUS,
    },
    [Chain.MANTLE]: {
        [Lender.KINZA]: MantleLenderId.KINZA,
        [Lender.LENDLE]: MantleLenderId.LENDLE,
        [Lender.AURELIUS]: MantleLenderId.AURELIUS,
        // comets
        [Lender.COMPOUND_V3_USDE]: MantleLenderId.COMPOUND_V3_USDE
    },
    [Chain.OP_MAINNET]: {
        [Lender.AAVE_V3]: OptimismLenderId.AAVE_V3,
        // comets
        [Lender.COMPOUND_V3_USDC]: OptimismLenderId.COMPOUND_V3_USDC,
        [Lender.COMPOUND_V3_WETH]: OptimismLenderId.COMPOUND_V3_WETH,
        [Lender.COMPOUND_V3_USDT]: OptimismLenderId.COMPOUND_V3_USDT,
        // venuses
        [Lender.VENUS]: OptimismLenderId.VENUS,
    },
    [Chain.ETHEREUM_MAINNET]: {
        [Lender.AAVE_V3]: EthereumLenderId.AAVE_V3,
        [Lender.AAVE_V3_PRIME]: EthereumLenderId.AAVE_V3_PRIME,
        [Lender.AAVE_V3_ETHER_FI]: EthereumLenderId.AAVE_V3_ETHER_FI,
        [Lender.SPARK]: EthereumLenderId.SPARK,
        [Lender.KINZA]: EthereumLenderId.KINZA,
        // avalons
        [Lender.AVALON_SOLV_BTC]: EthereumLenderId.AVALON_SOLV_BTC,
        [Lender.AVALON_SWELL_BTC]: EthereumLenderId.AVALON_SWELL_BTC,
        [Lender.AVALON_PUMP_BTC]: EthereumLenderId.AVALON_PUMP_BTC,
        [Lender.AVALON_EBTC_LBTC]: EthereumLenderId.AVALON_EBTC_LBTC,
        // zerolends
        [Lender.ZEROLEND_STABLECOINS_RWA]: EthereumLenderId.ZEROLEND_STABLECOINS_RWA,
        [Lender.ZEROLEND_ETH_LRTS]: EthereumLenderId.ZEROLEND_ETH_LRTS,
        [Lender.ZEROLEND_BTC_LRTS]: EthereumLenderId.ZEROLEND_BTC_LRTS,
        // comets
        [Lender.COMPOUND_V3_USDC]: EthereumLenderId.COMPOUND_V3_USDC,
        [Lender.COMPOUND_V3_WETH]: EthereumLenderId.COMPOUND_V3_WETH,
        [Lender.COMPOUND_V3_USDT]: EthereumLenderId.COMPOUND_V3_USDT,
        [Lender.COMPOUND_V3_WSTETH]: EthereumLenderId.COMPOUND_V3_WSTETH,
        [Lender.COMPOUND_V3_USDS]: EthereumLenderId.COMPOUND_V3_USDS,
        // venuses
        [Lender.VENUS]: EthereumLenderId.VENUS,
    },
    [Chain.TAIKO_ALETHIA]: {
        [Lender.HANA]: TaikoLenderId.HANA,
        [Lender.AVALON]: TaikoLenderId.AVALON,
        [Lender.AVALON_SOLV_BTC]: TaikoLenderId.AVALON_SOLV_BTC,
        [Lender.AVALON_USDA]: TaikoLenderId.AVALON_USDA,
        [Lender.MERIDIAN]: TaikoLenderId.MERIDIAN,
        [Lender.TAKOTAKO]: TaikoLenderId.TAKOTAKO
    }
}


export function getCompoundV3Approves(chainId: number) {
    let params: ApproveParamsStruct[] = []
    Object.entries(COMETS_PER_CHAIN_MAP[chainId]).map(([lender, comet]) => {
        const assets = COMPOUND_STYLE_RESERVE_ASSETS[lender][chainId]
        assets.map(token => {
            params.push({
                token,
                target: comet as any,
            })
        })

    })

    return params
}

export function getAaveForkDatas(chainId: number) {
    let params: BatchAddLenderTokensParamsStruct[] = []
    Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender, data]) => {
        const dataForChain = data[chainId]
        if (dataForChain) {
            const reserves = AAVE_STYLE_RESERVE_ASSETS[lender][chainId]
            const tokens = AAVE_STYLE_TOKENS[lender][chainId]
            reserves.forEach(underlying => {
                const data = tokens[underlying]
                params.push({
                    underlying,
                    collateralToken: data.aToken,
                    debtToken: data.vToken,
                    stableDebtToken: data.sToken,
                    lenderId: LENDER_TO_ID[chainId][lender]
                })
            })
        }
    })

    return params
}

export function getAaveForkApproveDatas(chainId: number) {
    let params: ApproveParamsStruct[] = []
    Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender, data]) => {
        const dataForChain = data[chainId]
        if (dataForChain) {
            const reserves = AAVE_STYLE_RESERVE_ASSETS[lender][chainId]
            reserves.forEach(underlying => {
                params.push({
                    token: underlying,
                    target: dataForChain.pool,
                })
            })

        }
    })
    return params
}