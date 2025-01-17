import { setTimeout } from "timers/promises";

export const MANTLE_CONFIGS = {
    maxFeePerGas: 0.02 * 1e9,
    maxPriorityFeePerGas: 0.02 * 1e9
}


export function getMantleConfig(n: number) {
    return {
        nonce: n,
        ...MANTLE_CONFIGS
    }
}


export const delay = async (ms: number) => {
    await setTimeout(ms)
}