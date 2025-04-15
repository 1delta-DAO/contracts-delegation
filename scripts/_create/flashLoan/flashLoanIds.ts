import { Lender } from "@1delta/asset-registry";
import { DexProtocol } from "../dex/dexs";

export const FLASH_LOAN_IDS: { [e: string]: number } = {
    /** Aave V3s */
    [Lender.AAVE_V3]: 0,
    [Lender.AAVE_V3_PRIME]: 1,
    [Lender.AAVE_V3_ETHER_FI]: 2,

    // reserve for more aave V3s

    [Lender.SPARK]: 10,

    // more exotics
    [Lender.HANA]: 11,
    [Lender.KINZA]: 12,
    [Lender.LENDOS]: 13,
    [Lender.MAGSIN]: 14,

    // zerolends
    [Lender.ZEROLEND]: 20,
    [Lender.ZEROLEND_STABLECOINS_RWA]: 21,
    [Lender.ZEROLEND_ETH_LRTS]: 22,
    [Lender.ZEROLEND_BTC_LRTS]: 23,
    [Lender.ZEROLEND_CROAK]: 24,
    [Lender.ZEROLEND_FOXY]: 25,

    // avalons
    [Lender.AVALON]: 50,
    [Lender.AVALON_SOLV_BTC]: 51,
    [Lender.AVALON_SWELL_BTC]: 52,
    [Lender.AVALON_PUMP_BTC]: 53,
    [Lender.AVALON_EBTC_LBTC]: 54,
    [Lender.AVALON_USDA]: 55,
    [Lender.AVALON_SKAIA]: 56,

    // exotic
    [Lender.YLDR]: 100,

    /** Aave V2s */
    [Lender.AAVE_V2]: 0,

    [Lender.AURELIUS]: 2,
    [Lender.LENDLE]: 1,
    [Lender.MERIDIAN]: 3,
    [Lender.TAKOTAKO]: 4,
    [Lender.TAKOTAKO_ETH]: 5,
    [Lender.NEREUS]: 6,
    [Lender.GRANARY]: 7,
    [Lender.LORE]: 8,
    [Lender.IRONCLAD_FINANCE]: 9,
    [Lender.MOLEND]: 10,
    [Lender.POLTER]: 11,
    [Lender.SEISMIC]: 12,
    [Lender.AGAVE]: 13,

    // Morphos
    [Lender.MORPHO_BLUE]: 0,

    /** Balancer V2 */
    [DexProtocol.BALANCER_V2]: 0,
    [DexProtocol.SYMMETRIC]: 1
}