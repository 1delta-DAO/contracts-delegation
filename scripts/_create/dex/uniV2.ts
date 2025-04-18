import { Chain } from "@1delta/asset-registry";
import { DexProtocol } from "./dexs";

export enum DexValidation {
    OVERRIDE = "OVERRIDE"
}

const uniswapV2InitHash = "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f";
const pancakeV2CodeHash = "0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5"
const uniV2CallbackSelector = "0x10d1e85c00000000000000000000000000000000000000000000000000000000"
const pancakeV2CallbackSelector = "0x8480081200000000000000000000000000000000000000000000000000000000"
const solidlyV2CallbackSelector = "0x9a7bff7900000000000000000000000000000000000000000000000000000000"
const UNISWAP_V2: UniswapV2Info = {
    factories: {
        [Chain.ETHEREUM_MAINNET]: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
        [Chain.ARBITRUM_ONE]: "0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9",
        [Chain.BASE]: "0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6",
        [Chain.AVALANCHE_C_CHAIN]: "0x9e5A52f57b3038F1B8EeE45F28b3C1967e22799C",
        [Chain.OP_MAINNET]: "0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf",
        [Chain.POLYGON_MAINNET]: "0x9e5A52f57b3038F1B8EeE45F28b3C1967e22799C",
        [Chain.BLAST]: "0x5C346464d33F90bABaf70dB6388507CC889C1070",
        [Chain.ZORA]: "0x0F797dC7efaEA995bB916f268D919d0a1950eE3C",
        [Chain.WORLD_CHAIN]: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
        // [Chain.SCROLL]: "",
        // [Chain.LINEA]: "",
        // [Chain.MANTLE]: "",
        // [Chain.TAIKO_ALETHIA]: "",
        // [Chain.GNOSIS]: "",
        // [Chain.SONIC_MAINNET]: "",
        // [Chain.INK]: "",
        // [Chain.HEMI_NETWORK]: ""
    },
    codeHash: { default: uniswapV2InitHash },
    callbackSelector: uniV2CallbackSelector,
    forkId: "0"
}

const PANCAKE_V2: UniswapV2Info = {
    factories: {
        [Chain.ETHEREUM_MAINNET]: "0x1097053Fd2ea711dad45caCcc45EfF7548fCB362",
        [Chain.ARBITRUM_ONE]: "0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E",
        [Chain.BASE]: "0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73",
        [Chain.LINEA]: "0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E",
        [Chain.OPBNB_MAINNET]: "0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E",
        [Chain.ZKSYNC_MAINNET]: "0xd03D8D566183F0086d8D09A84E1e30b58Dd5619d",
        [Chain.POLYGON_ZKEVM]: "0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E",
        // [Chain.POLYGON_MAINNET]: "",
        // [Chain.BLAST]: "",
        // [Chain.ZORA]: "",
        // [Chain.WORLD_CHAIN]: "",
        // [Chain.SCROLL]: "",
        // [Chain.LINEA]: "",
        // [Chain.MANTLE]: "",
        // [Chain.TAIKO_ALETHIA]: "",
        // [Chain.GNOSIS]: "",
        // [Chain.SONIC_MAINNET]: "",
        // [Chain.INK]: "",
        // [Chain.HEMI_NETWORK]: ""
    },
    codeHash: { default: pancakeV2CodeHash },
    callbackSelector: pancakeV2CallbackSelector,
    forkId: "0"
}



const SUSHI_V2: UniswapV2Info = {
    factories: {
        [Chain.ARBITRUM_ONE]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.ARBITRUM_NOVA]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.AVALANCHE_C_CHAIN]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.BASE]: "0x71524B4f93c58fcbF659783284E38825f0622859",
        [Chain.BLAST]: "0x42Fa929fc636e657AC568C0b5Cf38E203b67aC2b",
        [Chain.BOBA_NETWORK]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        // [Chain.BOBA_AVAX]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.BOBA_BNB_MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        // [Chain.BSC_TESTNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.BITTORRENT_CHAIN_MAINNET]: "0xB45e53277a7e0F1D35f2a77160e91e25507f1763",
        [Chain.CELO_MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.CORE_BLOCKCHAIN_MAINNET]: "0xB45e53277a7e0F1D35f2a77160e91e25507f1763",
        [Chain.ETHEREUM_MAINNET]: "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac",
        [Chain.FANTOM_OPERA]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.FILECOIN___MAINNET]: "0x9B3336186a38E1b6c21955d112dbb0343Ee061eE",
        // [Chain.FUJI]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.FUSE_MAINNET]: "0x43eA90e2b786728520e4f930d2A71a477BF2737C",
        // [Chain.GOERLI]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.HAQQ_NETWORK]: "0xB45e53277a7e0F1D35f2a77160e91e25507f1763",
        [Chain.HARMONY_MAINNET_SHARD_0]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        // [Chain.HARMONY_TESTNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.HUOBI_ECO_CHAIN_MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        // [Chain.HECO_TESTNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.KAVA]: "0xD408a20f1213286fB3158a2bfBf5bFfAca8bF269",
        // [Chain.KOVAN]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.LINEA]: "0xFbc12984689e5f15626Bad03Ad60160Fe98B303C",
        // [Chain.LOCALHOST]: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
        [Chain.POLYGON_MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.METIS_ANDROMEDA_MAINNET]: "0x580ED43F3BBa06555785C81c2957efCCa71f7483",
        [Chain.MOONBEAM]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.MOONRIVER]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        // [Chain.MUMBAI]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.OKXCHAIN_MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        // [Chain.OKEX_TESTNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.OP_MAINNET]: "0xFbc12984689e5f15626Bad03Ad60160Fe98B303C",
        [Chain.PALM]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.POLYGON_ZKEVM]: "0xB45e53277a7e0F1D35f2a77160e91e25507f1763",
        // [Chain.RINKEBY]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.ROOTSTOCK_MAINNET]: "0xB45e53277a7e0F1D35f2a77160e91e25507f1763",
        // [Chain.ROPSTEN]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.SCROLL]: "0xB45e53277a7e0F1D35f2a77160e91e25507f1763",
        // [Chain.SEPOLIA]: "0x734583f62Bb6ACe3c9bA9bd5A53143CA2Ce8C55A",
        [Chain.SKALE_EUROPA_HUB]: "0x1aaF6eB4F85F8775400C1B10E6BbbD98b2FF8483",
        [Chain.TELOS_EVM_MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.THUNDERCORE_MAINNET]: "0xB45e53277a7e0F1D35f2a77160e91e25507f1763",
        [Chain.GNOSIS]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.ZETACHAIN_MAINNET]: "0x33d91116e0370970444B0281AB117e161fEbFcdD",
        [Chain.HEMI_NETWORK]: "0x9B3336186a38E1b6c21955d112dbb0343Ee061eE",

    },
    codeHash: { default: uniswapV2InitHash },
    callbackSelector: uniV2CallbackSelector,
    forkId: "1"
}


const PASS: UniswapV2Info = {
    factories: {
        [Chain.HEMI_NETWORK]: "0x242c913Ff5FE010430A709baab977e88435b7EBF",

    },
    codeHash: { default: "0xd040a901beef1fe03d5f83aff62cc341aa8fa949dcdaa516b1adcfae94ada0db" },
    callbackSelector: uniV2CallbackSelector,
    forkId: "50"
}

const UBESWAP: UniswapV2Info = {
    factories: {
        [Chain.CELO_MAINNET]: "0x62d5b84bE28a183aBB507E125B384122D2C25fAE",

    },
    codeHash: { default: "0xb3b8ff62960acea3a88039ebcf80699f15786f1b17cebd82802f7375827a339c" },
    callbackSelector: uniV2CallbackSelector,
    forkId: "10"
}

const BISWAP_V2: UniswapV2Info = {
    factories: {
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x858E3312ed3A876947EA49d572A7C42DE08af7EE",
    },
    codeHash: { default: "0xfea293c909d87cd4153593f077b76bb7e94340200f4ee84211ae8e4f9bd7ffdf" },
    callbackSelector: "0x5b3bc4fe00000000000000000000000000000000000000000000000000000000", // BiswapCall
    forkId: "0"
}

const SHADOW_V2: UniswapV2Info = {
    factories: {
        [Chain.SONIC_MAINNET]: "0x2dA25E7446A70D7be65fd4c053948BEcAA6374c8",
    },
    codeHash: { default: "0x4ed7aeec7c0286cad1e282dee1c391719fc17fe923b04fb0775731e413ed3554" },
    callbackSelector: solidlyV2CallbackSelector,
    forkId: "131"
}

const KODO: UniswapV2Info = {
    factories: {
        [Chain.TAIKO_ALETHIA]: "0x535E02960574d8155596a73c7Ad66e87e37Eb6Bc",
    },
    codeHash: { default: "0x24364b5d47cc9af524ff2ae89d98c1c10f4a388556279eecb00622b5d727c99a" },
    callbackSelector: solidlyV2CallbackSelector,
    forkId: "132"
}

const VELOCIMETER: UniswapV2Info = {
    factories: {
        [Chain.MANTLE]: "0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C",
    },
    codeHash: { default: "0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879" },
    callbackSelector: solidlyV2CallbackSelector,
    forkId: "133"
}
const DYSTOPIA: UniswapV2Info = {
    factories: {
        [Chain.POLYGON_MAINNET]: "0x1d21Db6cde1b18c7E47B0F7F42f4b3F68b9beeC9",
    },
    codeHash: { default: "0x009bce6d7eb00d3d075e5bd9851068137f44bba159f1cde806a268e20baaf2e8" },
    callbackSelector: solidlyV2CallbackSelector,
    forkId: "134"
}
const RAMSES_V1: UniswapV2Info = {
    factories: {
        [Chain.ARBITRUM_ONE]: "0xAAA20D08e59F6561f242b08513D36266C5A29415",
        [Chain.MANTLE]: "0xAAA16c016BF556fcD620328f0759252E29b1AB57",
    },
    codeHash: {
        [Chain.ARBITRUM_ONE]: DexValidation.OVERRIDE,
        [Chain.MANTLE]: "0xbf2404274de2b11f05e5aebd49e508de933034cb5fa2d0ac3de8cbd4bcef47dc"
    },
    callbackSelector: solidlyV2CallbackSelector,
    forkId: "135"
}
/** special case, solidly with uni V2 callback selector */
const CAMELOT_V2: UniswapV2Info = {
    factories: {
        [Chain.ARBITRUM_ONE]: "0x6EcCab422D763aC031210895C81787E87B43A652",
    },
    codeHash: { default: "0xa856464ae65f7619087bc369daaf7e387dae1e5af69cfa7935850ebf754b04c1" },
    callbackSelector: uniV2CallbackSelector,
    forkId: "130"
}
const SWAPX_V2: UniswapV2Info = {
    factories: {
        [Chain.SONIC_MAINNET]: "0x05c1be79d3aC21Cc4B727eeD58C9B2fF757F5663",
    },
    codeHash: { default: "0x6c45999f36731ff6ab43e943fca4b5a700786bbb202116cf6633b32039161e05" },
    callbackSelector: solidlyV2CallbackSelector,
    forkId: "136"
}
const METROPOLIS_V2: UniswapV2Info = {
    factories: {
        [Chain.SONIC_MAINNET]: "0x1570300e9cFEC66c9Fb0C8bc14366C86EB170Ad0",
    },
    codeHash: { default: "0xb174fb9703cd825ac38ca3cf781a2750d5ee57f4268806e0bca9bcd3d74b67b5" },
    callbackSelector: "0xd1f6317800000000000000000000000000000000000000000000000000000000", // doCall
    forkId: "11"
}

const APESWAP_V2: UniswapV2Info = {
    factories: {
        [Chain.POLYGON_MAINNET]: '0xCf083Be4164828f00cAE704EC15a36D711491284',
        [Chain.ARBITRUM_ONE]: '0xCf083Be4164828f00cAE704EC15a36D711491284',
    },
    codeHash: {
        [Chain.POLYGON_MAINNET]: '0x511f0f358fe530cda0859ec20becf391718fdf5a329be02f4c95361f3d6a42d8',
        [Chain.ARBITRUM_ONE]: '0xae7373e804a043c4c08107a81def627eeb3792e211fb4711fcfe32f0e4c45fd5',
    },
    callbackSelector: "0xbecda36300000000000000000000000000000000000000000000000000000000", // apeCall 
    forkId: "12"
}

const WAULTSWAP_V2: UniswapV2Info = {
    factories: {
        [Chain.POLYGON_MAINNET]: '0xa98ea6356A316b44Bf710D5f9b6b4eA0081409Ef',
    },
    codeHash: {
        [Chain.POLYGON_MAINNET]: '0x1cdc2246d318ab84d8bc7ae2a3d81c235f3db4e113f4c6fdc1e2211a9291be47',
    },
    callbackSelector: "0x485f399400000000000000000000000000000000000000000000000000000000", // waultSwapCall 
    forkId: "13"
}
const DFYN: UniswapV2Info = {
    factories: {
        [Chain.POLYGON_MAINNET]: '0xE7Fb3e833eFE5F9c441105EB65Ef8b261266423B',
    },
    codeHash: {
        [Chain.POLYGON_MAINNET]: '0xf187ed688403aa4f7acfada758d8d53698753b998a3071b06f1b777f4330eaf3',
    },
    callbackSelector: uniV2CallbackSelector,
    forkId: "14"
}
const POLYCAT: UniswapV2Info = {
    factories: {
        [Chain.POLYGON_MAINNET]: '0x477Ce834Ae6b7aB003cCe4BC4d8697763FF456FA',
    },
    codeHash: {
        [Chain.POLYGON_MAINNET]: '0x3cad6f9e70e13835b4f07e5dd475f25a109450b22811d0437da51e66c161255a',
    },
    callbackSelector: uniV2CallbackSelector,
    forkId: "15"
}
const COMETH: UniswapV2Info = {
    factories: {
        [Chain.POLYGON_MAINNET]: '0x800b052609c355cA8103E06F022aA30647eAd60a',
    },
    codeHash: {
        [Chain.POLYGON_MAINNET]: '0x499154cad90a3563f914a25c3710ed01b9a43b8471a35ba8a66a056f37638542',
    },
    callbackSelector: uniV2CallbackSelector,
    forkId: "16"
}
const QUICKSWAP_V2: UniswapV2Info = {
    factories: {
        [Chain.POLYGON_MAINNET]: '0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32',
    },
    codeHash: {
        [Chain.POLYGON_MAINNET]: '0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f',
    },
    callbackSelector: uniV2CallbackSelector,
    forkId: "3"
}


const MERCHANT_MOE: UniswapV2Info = {
    factories: {
        [Chain.MANTLE]: '0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc',
    },
    codeHash: {
        [Chain.MANTLE]: DexValidation.OVERRIDE,
    },
    callbackSelector: "0xba85410f00000000000000000000000000000000000000000000000000000000", // moeCall
    forkId: "0"
}

interface UniswapV2Info {
    factories: { [chain: string]: string },
    codeHash: { [chainOrDefault: string]: string },
    callbackSelector: string,
    forkId: string
}

export const UNISWAP_V2_FORKS: { [s: string]: UniswapV2Info } = {
    [DexProtocol.UNISWAP_V2]: UNISWAP_V2,
    [DexProtocol.SUSHISWAP_V2]: SUSHI_V2,
    [DexProtocol.PANCAKESWAP_V2]: PANCAKE_V2,
    [DexProtocol.PASS]: PASS,
    [DexProtocol.BISWAP_V2]: BISWAP_V2,
    [DexProtocol.UBESWAP_V2]: UBESWAP,
    [DexProtocol.METROPOLIS_V2]: METROPOLIS_V2,
    [DexProtocol.APESWAP]: APESWAP_V2,
    [DexProtocol.WAULTSWAP]: WAULTSWAP_V2,
    [DexProtocol.DFYN]: DFYN,
    [DexProtocol.POLYCAT]: POLYCAT,
    [DexProtocol.COMETH]: COMETH,
    [DexProtocol.QUICKSWAP_V2]: QUICKSWAP_V2,
    [DexProtocol.MERCHANT_MOE]: MERCHANT_MOE,

    "SHADOW_V2": SHADOW_V2,
    // solidlies go without the stable & volatile
    "CAMELOT_V2": CAMELOT_V2,
    "VELOCIMETER": VELOCIMETER,
    "DYSTOPIA": DYSTOPIA,
    "RAMSES_V1": RAMSES_V1,
    "KODO": KODO,
    "SWAPX_V2": SWAPX_V2,
}
