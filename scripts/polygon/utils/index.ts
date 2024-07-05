// 
// Base: 65.992920355 Gwei |Max: 111.630131289 Gwei |Max Priority: 30 Gwei
const POLYGON_CONFIGS = {
    maxFeePerGas: 250 * 1e9,
    maxPriorityFeePerGas: 35 * 1e9
}


export function getPolygonConfig(n?: number) {
    return {
        ...n ? { nonce: n } : {},
        ...POLYGON_CONFIGS
    }
}
