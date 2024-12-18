
export const TAIKO_CONFIGS = {
    maxFeePerGas: 150000001,
    maxPriorityFeePerGas: 150000001
}

export function getTaikoConfig(n: number) {
    return {
        nonce: n,
        ...TAIKO_CONFIGS
    }
}
