
const POLYGON_CONFIGS = {
    // none atm
}


export function getPolygonConfig(n?: number) {
    return {
        ...n ? { nonce: n } : {},
        ...POLYGON_CONFIGS
    }
}
