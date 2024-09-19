
export const TAIKO_CONFIGS = {
    maxFeePerGas: 50000001,
    maxPriorityFeePerGas: 50000001
}

export function getTaikoConfig(n: number) {
    return {
        nonce: n,
        ...TAIKO_CONFIGS
    }
}
