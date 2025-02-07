
export namespace CompoundV3Arbitrum {
    export const COMET_USDT = '0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07'
    export const COMET_USDC = '0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf'
    export const COMET_WETH = '0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486'
    export const COMET_USDCE = '0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA'

    export const COMET_DATAS = {
        USDC: {
            comet: COMET_USDC,
            assets: [
                "USDC",
                "WSTETH",
                "EZETH",
                "WETH",
                "ARB",
                "WBTC",
                "WUSDM",
                "GMX"
            ]
        },
        USDCE: {
            comet: COMET_USDCE,
            assets: [
                "USDCE",
                "WETH",
                "ARB",
                "WBTC",
                "GMX"
            ]
        },
        WETH: {
            comet: COMET_WETH,
            assets: [
                "WETH",
                "USDC",
                "RSETH",
                "WSTETH",
                "EZETH",
                "RETH",
                "USDT",
                "WBTC",
                "WEETH",
            ]
        },
        USDT: {
            comet: COMET_USDT,
            assets: [
                "USDT",
                "WETH",
                "ARB",
                "GMX",
                "WSTETH",
                "WBTC",
            ]
        },
    }
}