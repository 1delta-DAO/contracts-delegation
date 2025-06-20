import { Chain } from "@1delta/asset-registry"

export const DEPLOY_FACTORY = "0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"

// forwarder: also deployed on all those chains
export const FORWARDER = "0xfCa1154C643C32638AEe9a43eeE7f377f515c801"

export const COMPOSER_LOGICS = {
    [Chain.ARBITRUM_ONE]: "0xbaEe36c9ef69b0F8454e379314c7CBA628Fc6B61",
    [Chain.BASE]: "0x79f4061BF049c5c6CAC6bfe2415c2460815F4ac7",
    [Chain.OP_MAINNET]: "0x4aEA1CE479BF7E036bBB6826A2bF084bce6560a0",
    [Chain.POLYGON_MAINNET]: "0x4a7CAF7b2b44F14b72BF56fb189385e7EAAA957c",
    [Chain.SONIC_MAINNET]: "0x6Bc6aCB905c1216B0119C87Bf9E178ce298310FA",
    [Chain.HEMI_NETWORK]: "0x830d7Fb34Cf45BD0F9A5A8f4D899998c692541e2",
    [Chain.TAIKO_ALETHIA]: "0x868E267F80dd4d9cfe45b17fCB41Cf9894E72972",
    [Chain.METIS_ANDROMEDA_MAINNET]: "0x5c4F2eACBdc1EB38F839bDDD7620E250a36819D4",
    [Chain.GNOSIS]: "0x8e24cfc19c6c00c524353cb8816f5f1c2f33c201",
    [Chain.AVALANCHE_C_CHAIN]: '0x816EBC5cb8A5651C902Cb06659907A93E574Db0B',
    [Chain.MODE]: '0x816EBC5cb8A5651C902Cb06659907A93E574Db0B',
    [Chain.SCROLL]: '0x816EBC5cb8A5651C902Cb06659907A93E574Db0B',
    [Chain.CORE_BLOCKCHAIN_MAINNET]: "0xf9438f2b1c63D8dAC24311256F5483D7f7575863",
    [Chain.FANTOM_OPERA]: "0xf9438f2b1c63D8dAC24311256F5483D7f7575863",
    [Chain.BNB_SMART_CHAIN_MAINNET]: "0xf9438f2b1c63D8dAC24311256F5483D7f7575863",
    [Chain.MANTLE]: "0xcF5a5AC7796d4230263880d4Ec078D3513cE7E6C",
}

export const COMPOSER_PROXIES = {
    [Chain.ARBITRUM_ONE]: "0x05f3f58716a88A52493Be45aA0871c55b3748f18",
    [Chain.OP_MAINNET]: "0xCDef0A216fcEF809258aA4f341dB1A5aB296ea72",
    [Chain.POLYGON_MAINNET]: "0xFd245e732b40b6BF2038e42b476bD06580585326",
    [Chain.BASE]: "0xB7ea94340e65CC68d1274aE483dfBE593fD6f21e",
    [Chain.SONIC_MAINNET]: "0x8E24CfC19c6C00c524353CB8816f5f1c2F33c201",
    [Chain.HEMI_NETWORK]: "0x79f4061BF049c5c6CAC6bfe2415c2460815F4ac7",
    [Chain.TAIKO_ALETHIA]: "0x594cE4B82A81930cC637f1A59afdFb0D70054232",
    [Chain.METIS_ANDROMEDA_MAINNET]: "0xCe434378adacC51d54312c872113D687Ac19B516",
    [Chain.GNOSIS]: "0xcb6eb8df68153cebf60e1872273ef52075a5c297",
    [Chain.AVALANCHE_C_CHAIN]: '0x8E24CfC19c6C00c524353CB8816f5f1c2F33c201',
    [Chain.MODE]: '0x8E24CfC19c6C00c524353CB8816f5f1c2F33c201',
    [Chain.SCROLL]: '0x8E24CfC19c6C00c524353CB8816f5f1c2F33c201',
    [Chain.CORE_BLOCKCHAIN_MAINNET]: "0x816EBC5cb8A5651C902Cb06659907A93E574Db0B",
    [Chain.FANTOM_OPERA]: "0x816EBC5cb8A5651C902Cb06659907A93E574Db0B",
    [Chain.BNB_SMART_CHAIN_MAINNET]: "0x816EBC5cb8A5651C902Cb06659907A93E574Db0B",
    [Chain.MANTLE]: "0x5c019a146758287c614fe654caec1ba1caf05f4e",
}

export const PROXY_ADMINS = {
    [Chain.ARBITRUM_ONE]: "0x492d53456Cc219A755Ac5a2d8598fFd6F47A9fD1",
    [Chain.OP_MAINNET]: "0x9acc4fbbe3237e8f04173eca2c5b19c277305f56",
    [Chain.HEMI_NETWORK]: "0x684892E4BB52FD233416331Fa142f651ec5A2044",
    [Chain.TAIKO_ALETHIA]: "0x06289dbafd2a697179a401e86bd2a9322f57bedf",
    [Chain.POLYGON_MAINNET]: "0xdAf4eA0785E33F710A186CA5330Bd26837f96765",
    [Chain.SONIC_MAINNET]: "0xBb7EAaAF2C7208384F6297C2b73935D257698c78",
    [Chain.BASE]: "0x983B147a98bEAD1d4986B4c4c74c1984d0811Eb5",
    [Chain.METIS_ANDROMEDA_MAINNET]: "0xAd723f9A94D8b295781311ca4Ec31D5aBAe07c4f",
    [Chain.GNOSIS]: "0x36908c085e96782e67d4aebff6900e77da415570",
    [Chain.AVALANCHE_C_CHAIN]: '0xBb7EAaAF2C7208384F6297C2b73935D257698c78',
    [Chain.MODE]: '0xBb7EAaAF2C7208384F6297C2b73935D257698c78',
    [Chain.SCROLL]: '0xbb7eaaaf2c7208384f6297c2b73935d257698c78',
    [Chain.CORE_BLOCKCHAIN_MAINNET]: "0xb63E6455858887C8F6bda75C44c41570be989597",
    [Chain.FANTOM_OPERA]: "0xb63e6455858887c8f6bda75c44c41570be989597",
    [Chain.BNB_SMART_CHAIN_MAINNET]: "0xb63e6455858887c8f6bda75c44c41570be989597",
    [Chain.MANTLE]: "0xe717cf8affa37c6e03c986452a19348ab6cb6197",
}