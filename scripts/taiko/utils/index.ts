
export const TAIKO_CONFIGS = {

}

export function getTaikoConfig(n: number) {
    return {
        nonce: n,
        ...TAIKO_CONFIGS
    }
}
