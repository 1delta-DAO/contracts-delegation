import { Chain } from "@1delta/asset-registry"

export const DEPLOY_FACTORY = "0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"

// forwarder: also deployed on all those chains
export const FORWARDER = "0xfca11Db2b5DE60DF9a2C81233333a449983B4101"

export const COMPOSER_LOGICS = {
    [Chain.ARBITRUM_ONE]: "0x541548dA7985e6DAc5103e249CfBb3906156C73B",
    [Chain.BASE]: "0x3375B2EF9C4D2c6434d39BBE5234c5101218500d",
    [Chain.OP_MAINNET]: "0xFc107f469A92c0de7B3105B802584CD6c7D710C2",
    [Chain.POLYGON_MAINNET]: "0x1DD5D0659e5e525f85B2d95f846062e55C60f55E",
    [Chain.SONIC_MAINNET]: "0x816EBC5cb8A5651C902Cb06659907A93E574Db0B"
}

export const COMPOSER_PROXIES = {
    [Chain.ARBITRUM_ONE]: "0x05f3f58716a88A52493Be45aA0871c55b3748f18",
    [Chain.OP_MAINNET]: "0xCDef0A216fcEF809258aA4f341dB1A5aB296ea72",
    [Chain.POLYGON_MAINNET]: "0xFd245e732b40b6BF2038e42b476bD06580585326",
    [Chain.BASE]: "0xB7ea94340e65CC68d1274aE483dfBE593fD6f21e",
    [Chain.SONIC_MAINNET]: "0x8E24CfC19c6C00c524353CB8816f5f1c2F33c201"
}

export const PROXY_ADMINS = {
    [Chain.ARBITRUM_ONE]: "0x492d53456Cc219A755Ac5a2d8598fFd6F47A9fD1",
    [Chain.OP_MAINNET]: "0x9acc4fbbe3237e8f04173eca2c5b19c277305f56",
}