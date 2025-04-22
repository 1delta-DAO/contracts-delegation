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
}