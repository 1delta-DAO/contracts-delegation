import { AddressMap } from "../../_shared"

export namespace CompoundV3Polygon {
    export const COMET_USDC = '0xF25212E676D1F7F89Cd72fFEe66158f541246445'
    export const COMET_USDT = '0xaeB318360f27748Acb200CE616E389A6C9409a07'

    export const COMET_USDC_UNDERLYINGS: AddressMap = {
        WMATIC: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
        USDC: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
        WBTC: '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6',
        stMATIC: '0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4',
        MaticX: '0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6',
        WETH: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
    }


    export const COMET_DATAS = {
        USDC: {
            comet: COMET_USDC,
            assets: [
                "WMATIC",
                "USDC",
                "WBTC",
                "stMATIC",
                "MaticX",
                "WETH",
            ]
        },
        USDCE: {
            comet: COMET_USDT,
            assets: [
                "WMATIC",
                "USDT",
                "WBTC",
                "stMATIC",
                "MaticX",
                "WETH",
            ]
        },
    }
}