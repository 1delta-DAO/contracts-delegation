
export const ARBITRUM_CONFIGS = {
    maxFeePerGas: 0.01 * 1e9,
    maxPriorityFeePerGas: 0.01* 1e9
}


export function getArbitrumConfig(n: number) {
    return {
        nonce: n,
        ...ARBITRUM_CONFIGS
    }
}
