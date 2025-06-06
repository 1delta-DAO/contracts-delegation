import { Chain } from "@1delta/asset-registry";
import { DexProtocol } from "@1delta/dex-registry";

/**
 * do not include DEXs on these chains for the hard-coded part
 * due to insufficient liquidity 
 */
export const DEX_TO_CHAINS_EXCLUSIONS: { [dex: string]: string[] } = {
    [DexProtocol.SQUADSWAP_V3]: [
        Chain.ARBITRUM_ONE,
        Chain.BASE,
        Chain.BLAST,
        Chain.POLYGON_MAINNET,
        Chain.OP_MAINNET,
    ],
    [DexProtocol.SQUADSWAP_V2]: [
        Chain.ARBITRUM_ONE,
        Chain.BASE,
        Chain.BLAST,
        Chain.POLYGON_MAINNET,
        Chain.OP_MAINNET,
    ],
    [DexProtocol.WAGMI]: [
        Chain.ZKLINK_NOVA_MAINNET,
        Chain.ETHEREUM_MAINNET,
        Chain.ZKSYNC_MAINNET,
        Chain.FANTOM_OPERA,
        Chain.BASE,
        Chain.POLYGON_MAINNET,
        Chain.BNB_SMART_CHAIN_MAINNET,
        Chain.OP_MAINNET,
        Chain.AVALANCHE_C_CHAIN,
    ],
    [DexProtocol.DACKIESWAP_V3]: [
        Chain.ARBITRUM_ONE,
        Chain.X_LAYER_MAINNET,
        Chain.OP_MAINNET,
        Chain.LINEA,
        Chain.MODE,
        Chain.BLAST,
        Chain.WORLD_CHAIN,
    ],
    [DexProtocol.AXION_V2]: [
        Chain.TAIKO_ALETHIA
    ],
}