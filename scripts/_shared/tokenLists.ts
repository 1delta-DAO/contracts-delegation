export type RawCurrency = {
    chainId: string;
    address: string;
    decimals: number;
    symbol?: string;
    name?: string;
    logoURI?: string;
    tags?: string[];
    props?: {
        [key: string]: any;
    };
    assetGroup?: string;
};

export interface DeltaTokenList {
    chainId: string;
    version: string;
    list: Record<string, RawCurrency>;
    mainTokens: string[];
}

export type TokenListsRecord = Record<string, Record<string, RawCurrency>>;

let cachedTokenLists: TokenListsRecord | null = null;
let loadPromise: Promise<TokenListsRecord> | null = null;

const unallowedChars = ["[", "]", "₮"];

function hasUnallowedChars(symbol: string | undefined): boolean {
    if (!symbol) return false;
    return unallowedChars.some((char) => symbol.includes(char));
}

const getListUrl = (chainId: string) => `https://raw.githubusercontent.com/1delta-DAO/token-lists/main/${chainId}.json`;

async function fetchList(chainId: string): Promise<DeltaTokenList | null> {
    try {
        const url = getListUrl(chainId);
        const response = await fetch(url);
        if (!response.ok) {
            console.warn(`Failed to fetch asset list for chain ${chainId}: ${response.status} ${response.statusText}`);
            return null;
        }
        const data = (await response.json()) as DeltaTokenList;
        return data;
    } catch (error) {
        console.warn(`Error fetching asset list for chain ${chainId}:`, error);
        return null;
    }
}

export async function loadTokenLists(chainIds: string[]): Promise<TokenListsRecord> {
    if (cachedTokenLists) return cachedTokenLists;
    if (loadPromise) return loadPromise;

    loadPromise = (async () => {
        const lists: TokenListsRecord = {};

        for (const chainId of chainIds) {
            const list = await fetchList(chainId);
            if (!list || !list.list) continue;

            const normalized: Record<string, RawCurrency> = {};
            for (const [address, token] of Object.entries(list.list)) {
                if (!hasUnallowedChars(token.symbol)) {
                    normalized[address.toLowerCase()] = token;
                }
            }

            lists[chainId] = normalized;
        }

        cachedTokenLists = lists;
        return lists;
    })();

    return loadPromise;
}

export function getTokenFromCache(chainId: string, address: string): RawCurrency | undefined {
    return cachedTokenLists?.[chainId]?.[address.toLowerCase()];
}

export function getTokenListsCache(): TokenListsRecord | null {
    return cachedTokenLists;
}

export function isTokenListsReady(): boolean {
    return cachedTokenLists !== null;
}
