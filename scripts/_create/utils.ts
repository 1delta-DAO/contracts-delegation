import {initializeChainData, initializeLenderData} from "@1delta/data-sdk";

const baseUrl = "https://raw.githubusercontent.com/1delta-DAO/lender-metadata/main";
const aavePools = baseUrl + "/config/aave-pools.json";
const aaveOracles = baseUrl + "/data/aave-oracles.json";
const morphoOracles = baseUrl + "/data/morpho-oracles.json";
const compoundV2Pools = baseUrl + "/config/compound-v2-pools.json";
const compoundV3Pools = baseUrl + "/config/compound-v3-pools.json";
// const initPools = baseUrl + '/config/init-pools.json'
const morphoPools = baseUrl + "/config/morpho-pools.json";

const aaveReserves = baseUrl + "/data/aave-reserves.json";
const compoundV2Reserves = baseUrl + "/data/compound-v2-reserves.json";
const compoundV3Reserves = baseUrl + "/data/compound-v3-reserves.json";
const initConfig = baseUrl + "/data/init-config.json";
const aaveTokens = baseUrl + "/data/aave-tokens.json";
const compoundV2CTokens = baseUrl + "/data/compound-v2-c-tokens.json";
const compoundV3Base = baseUrl + "/data/compound-v3-base-data.json";
const baseUrlChains = "https://raw.githubusercontent.com/1delta-DAO/chains/main";

const chains = baseUrlChains + "/data.json";

export function inititalizeAllData(params: any) {
    const {chainsOverride, ...lenderOverrides} = params;

    initializeLenderData(lenderOverrides);

    initializeChainData({chainsOverride});
}

export async function fetchLenderMetaFromDirAndInitialize() {
    const {
        aavePoolsOverride,
        compoundV2PoolsOverride,
        compoundV3PoolsOverride,
        // initPoolsOverride,
        morphoPoolsOverride,
        aaveReservesOverride,
        compoundV2ReservesOverride,
        compoundV3ReservesOverride,
        initConfigOverride,
        aaveTokensOverride,
        compoundV2TokensOverride,
        compoundV3BaseDataOverride,
        aaveOraclesOverride,
        morphoOraclesOverride,
        chainsOverride,
    } = await fetchLenderMetaFromDir();

    initializeLenderData({
        aaveTokensOverride,
        aavePoolsOverride,
        compoundV3PoolsOverride,
        compoundV3BaseDataOverride,
        morphoPoolsOverride,
        compoundV2TokensOverride,
        compoundV2PoolsOverride,
        initConfigOverride,
        aaveReservesOverride,
        compoundV3ReservesOverride,
        compoundV2ReservesOverride,
        aaveOraclesOverride,
        morphoOraclesOverride,
    });

    initializeChainData({chainsOverride});
}

export async function fetchLenderMetaFromDir() {
    const promises = [
        aavePools,
        compoundV2Pools,
        compoundV3Pools,
        // initPools,
        morphoPools,
        aaveReserves,
        compoundV2Reserves,
        compoundV3Reserves,
        initConfig,
        aaveTokens,
        compoundV2CTokens,
        compoundV3Base,
        aaveOracles,
        morphoOracles,
        chains,
    ].map(async (a) => fetch(a).then(async (b) => await b.json()));

    const [
        aavePoolsOverride,
        compoundV2PoolsOverride,
        compoundV3PoolsOverride,
        // initPoolsOverride,
        morphoPoolsOverride,
        aaveReservesOverride,
        compoundV2ReservesOverride,
        compoundV3ReservesOverride,
        initConfigOverride,
        aaveTokensOverride,
        compoundV2TokensOverride,
        compoundV3BaseDataOverride,
        aaveOraclesOverride,
        morphoOraclesOverride,
        chainsOverride,
    ] = await Promise.all(promises);

    return {
        aavePoolsOverride,
        compoundV2PoolsOverride,
        compoundV3PoolsOverride,
        // initPoolsOverride,
        morphoPoolsOverride,
        aaveReservesOverride,
        compoundV2ReservesOverride,
        compoundV3ReservesOverride,
        initConfigOverride,
        aaveTokensOverride,
        compoundV2TokensOverride,
        compoundV3BaseDataOverride,
        aaveOraclesOverride,
        morphoOraclesOverride,
        chainsOverride,
    };
}
