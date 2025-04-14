import { Chain } from "@1delta/asset-registry";
import { DexProtocol } from "./dexs";

const UNISWAP_V4 = {
    pm: {
        [Chain.ETHEREUM_MAINNET]: "0x000000000004444c5dc75cB358380D2e3dE08A90",
        [Chain.ARBITRUM_ONE]: "0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32",
        [Chain.AVALANCHE_C_CHAIN]: "0x06380C0e0912312B5150364B9DC4542BA0DbBc85",
        [Chain.BASE]: "0x498581fF718922c3f8e6A244956aF099B2652b2b",
        [Chain.BLAST]: "0x1631559198A9e474033433b2958daBC135ab6446",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF",
        [Chain.OP_MAINNET]: "0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3",
        [Chain.POLYGON_MAINNET]: "0x67366782805870060151383F4BbFF9daB53e5cD6",
        [Chain.WORLD_CHAIN]: "0xb1860D529182ac3BC1F51Fa2ABd56662b7D13f33",
    },
    forkId: "0"
}

interface UniswapV4Info {
    pm: {
        [chainId: string]: string
    },
    forkId: string
}

export const UNISWAP_V4_FORKS: { [s: string]: UniswapV4Info } = {
    [DexProtocol.UNISWAP_V4]: UNISWAP_V4
}