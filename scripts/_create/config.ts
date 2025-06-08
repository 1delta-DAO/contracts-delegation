import { Chain, CHAIN_INFO } from "@1delta/asset-registry";

export const CREATE_CHAIN_IDS = [
    Chain.ARBITRUM_ONE,
    Chain.HEMI_NETWORK,
    Chain.BNB_SMART_CHAIN_MAINNET,
    Chain.METIS_ANDROMEDA_MAINNET,
    Chain.BASE,
    Chain.POLYGON_MAINNET,
    Chain.TAIKO_ALETHIA,
    Chain.MANTLE,
    Chain.CELO_MAINNET,
    Chain.GNOSIS,
    Chain.AVALANCHE_C_CHAIN,
    Chain.SONIC_MAINNET,
    Chain.OP_MAINNET,
    Chain.SCROLL,
    Chain.LINEA,
    Chain.SONEIUM,
];

export function sortForks<T>(arr: T[], field: keyof T) {
    let unis: T[] = [];
    let sushis: T[] = [];
    let pancakes: T[] = [];
    let rest: T[] = [];

    arr.forEach((a) => {
        if (String(a[field]).includes("UNISWAP")) {
            unis.push(a);
        } else if (String(a[field]).includes("SUSHI")) {
            sushis.push(a);
        } else if (String(a[field]).includes("PANCAKE")) {
            pancakes.push(a);
        } else rest.push(a);
    });
    return [...unis, ...sushis, ...pancakes, ...rest];
}

export function toCamelCaseWithFirstUpper(str: string) {
    const camel = str.replace(/-([a-z])/g, (_, char) => char.toUpperCase());
    return camel.charAt(0).toUpperCase() + camel.slice(1);
}

export const getChainKey = (chainId: string) => CHAIN_INFO[chainId].key!;
export const getChainEnum = (chainId: string) => CHAIN_INFO[chainId].enum!;
