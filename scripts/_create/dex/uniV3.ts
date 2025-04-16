import { Chain } from "@1delta/asset-registry";
import { DexProtocol } from "./dexs";

const uniswapV3InitHash = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";

const uniswapV3CallbackSelector = "0xfa461e3300000000000000000000000000000000000000000000000000000000";
const pancakeV3CallbackSelector = "0x23a69e7500000000000000000000000000000000000000000000000000000000";
const algebraV3CallbackSelector = "0x2c8958f600000000000000000000000000000000000000000000000000000000";

const UNISWAP_V3: UniswapV3Info = {
    factories: {
        [Chain.ETHEREUM_MAINNET]: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        [Chain.BASE]: "0x33128a8fC17869897dcE68Ed026d694621f6FDfD",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7",
        [Chain.AVALANCHE_C_CHAIN]: "0x740b1c1de25031C31FF4fC9A62f554A55cdC1baD",
        [Chain.BLAST]: "0x792edAdE80af5fC680d96a2eD80A44247D2Cf6Fd",
        [Chain.SCROLL]: "0x70C62C8b8e801124A4Aa81ce07b637A3e83cb919",
        [Chain.LINEA]: "0x31FAfd4889FA1269F7a13A66eE0fB458f27D72A9",
        [Chain.MANTLE]: "0x0d922Fb1Bc191F64970ac40376643808b4B74Df9",
        [Chain.TAIKO_ALETHIA]: "0x75FC67473A91335B5b8F8821277262a13B38c9b3",
        [Chain.WORLD_CHAIN]: "0x7a5028BDa40e7B173C278C5342087826455ea25a",
        [Chain.GNOSIS]: "0xe32F7dD7e3f098D518ff19A22d5f028e076489B1",
        [Chain.SONIC_MAINNET]: "0xcb2436774C3e191c85056d248EF4260ce5f27A9D",
        [Chain.INK]: "0x640887A9ba3A9C53Ed27D0F7e8246A4F933f3424",
        [Chain.HEMI_NETWORK]: "0x346239972d1fa486FC4a521031BC81bFB7D6e8a4",
        [Chain.OP_MAINNET]: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        [Chain.ARBITRUM_ONE]: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        [Chain.POLYGON_MAINNET]: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        [Chain.CELO_MAINNET]: "0xAfE208a311B21f13EF87E33A90049fC17A7acDEc",
        [Chain.ZKSYNC_MAINNET]: "0x8FdA5a7a8dCA67BBcDd10F02Fa0649A937215422",
        [Chain.BOBA_NETWORK]: "0xFFCd7Aed9C627E82A765c3247d562239507f6f1B",
        [Chain.POLYGON_ZKEVM]: "0xff83c3c800Fec21de45C5Ec30B69ddd5Ee60DFC2",
        [Chain.MOONBEAM]: "0x28f1158795A3585CaAA3cD6469CD65382b89BB70",
        [Chain.FILECOIN___MAINNET]: "0xB4C47eD546Fc31E26470a186eC2C5F19eF09BA41",
        [Chain.ROOTSTOCK_MAINNET]: "0xaF37EC98A00FD63689CF3060BF3B6784E00caD82",
        [Chain.ZORA]: "0x7145F8aeef1f6510E92164038E1B6F8cB2c42Cbb",
        [Chain.SEI_NETWORK]: "0x75FC67473A91335B5b8F8821277262a13B38c9b3",
        [Chain.MANTA_PACIFIC_MAINNET]: "0x06D830e15081f65923674268121FF57Cc54e4e23",
        [Chain.REDSTONE]: "0xece75613Aa9b1680f0421E5B2eF376DF68aa83Bb",
        [Chain.LISK]: "0x0d922Fb1Bc191F64970ac40376643808b4B74Df9",
        [Chain.BOB]: "0xcb2436774C3e191c85056d248EF4260ce5f27A9D",
        // [Chain.ZERO]: "0xA1160e73B63F322ae88cC2d8E700833e71D0b2a1",
        [Chain.METAL_L2]: "0xcb2436774C3e191c85056d248EF4260ce5f27A9D",
        [Chain.CYBER_MAINNET]: "0x9701158fcF072c6852FD83B54D237e0cf5910C08",
        [Chain.SAGA]: "0x454050C4c9190390981Ac4b8d5AFcd7aC65eEffa",
        [Chain.CORN]: "0xcb2436774C3e191c85056d248EF4260ce5f27A9D",
        [Chain.SHAPE]: "0xeCf9288395797Da137f663a7DD0F0CDF918776F8",
        [Chain.ABSTRACT]: "0xA1160e73B63F322ae88cC2d8E700833e71D0b2a1",
        [Chain.TELOS_EVM_MAINNET]: "0xcb2436774C3e191c85056d248EF4260ce5f27A9D",
        [Chain.LIGHTLINK_PHOENIX_MAINNET]: "0xcb2436774C3e191c85056d248EF4260ce5f27A9D",
        [Chain.GOAT_NETWORK]: "0xcb2436774C3e191c85056d248EF4260ce5f27A9D",

    },
    codeHash: { default: uniswapV3InitHash },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "0"
}

const SUSHISWAP_V3: UniswapV3Info = {
    factories: {
        [Chain.ARBITRUM_ONE]: "0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e",
        [Chain.ARBITRUM_NOVA]: "0xaa26771d497814E81D305c511Efbb3ceD90BF5bd",
        [Chain.AVALANCHE_C_CHAIN]: "0x3e603C14aF37EBdaD31709C4f848Fc6aD5BEc715",
        [Chain.BASE]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.BLAST]: "0x7680D4B43f3d1d54d6cfEeB2169463bFa7a6cf0d",
        [Chain.BOBA_NETWORK]: "0x0BE808376Ecb75a5CF9bB6D237d16cd37893d904",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x126555dd55a39328F69400d6aE4F782Bd4C34ABb",
        [Chain.BITTORRENT_CHAIN_MAINNET]: "0xBBDe1d67297329148Fe1ED5e6B00114842728e65",
        [Chain.CELO_MAINNET]: "0x93395129bd3fcf49d95730D3C2737c17990fF328",
        [Chain.CORE_BLOCKCHAIN_MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.ETHEREUM_MAINNET]: "0xbACEB8eC6b9355Dfc0269C18bac9d6E2Bdc29C4F",
        [Chain.FANTOM_OPERA]: "0x7770978eED668a3ba661d51a773d3a992Fc9DDCB",
        [Chain.FILECOIN___MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.FUSE_MAINNET]: "0x1b9d177CcdeA3c79B6c8F40761fc8Dc9d0500EAa",
        [Chain.GNOSIS]: "0xf78031CBCA409F2FB6876BDFDBc1b2df24cF9bEf",
        [Chain.HAQQ_NETWORK]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.KAVA]: "0x1e9B24073183d5c6B7aE5FB4b8f0b1dd83FDC77a",
        [Chain.LINEA]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.METIS_ANDROMEDA_MAINNET]: "0x145d82bCa93cCa2AE057D1c6f26245d1b9522E6F",
        [Chain.MOONBEAM]: "0x2ecd58F51819E8F8BA08A650BEA04Fc0DEa1d523",
        [Chain.MOONRIVER]: "0x2F255d3f3C0A3726c6c99E74566c4b18E36E3ce6",
        [Chain.OPBNB_MAINNET]: "0x9c6522117e2ed1fE5bdb72bb0eD5E3f2bdE7DBe0",
        [Chain.POLYGON_MAINNET]: "0x917933899c6a5F8E37F31E19f92CdBFF7e8FF0e2",
        [Chain.POLYGON_ZKEVM]: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
        [Chain.ROOTSTOCK_MAINNET]: "0x46B3fDF7b5CDe91Ac049936bF0bDb12c5d22202e",
        [Chain.SCROLL]: "0x46B3fDF7b5CDe91Ac049936bF0bDb12c5d22202e",
        [Chain.SKALE_EUROPA_HUB]: "0x51d15889b66A2c919dBbD624d53B47a9E8feC4bB",
        [Chain.THUNDERCORE_MAINNET]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        [Chain.ZETACHAIN_MAINNET]: "0xB45e53277a7e0F1D35f2a77160e91e25507f1763",
        [Chain.HEMI_NETWORK]: "0xCdBCd51a5E8728E0AF4895ce5771b7d17fF71959",

    },
    codeHash: {
        default: uniswapV3InitHash,
        [Chain.BLAST]: "0x8e13daee7f5a62e37e71bf852bcd44e7d16b90617ed2b17c24c2ee62411c5bae",
    },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "1"
}

const solidlyV3Factory = "0x70Fe4a44EA505cFa3A57b95cF2862D4fd5F0f687"
const solidlyV3InitHash = "0xe9b68c5f77858eecac2e651646e208175e9b1359d68d0e14fc69f8c54e5010bf";

const SOLIDLY_V3: UniswapV3Info = {
    factories: {
        [Chain.ETHEREUM_MAINNET]: solidlyV3Factory,
        [Chain.BASE]: solidlyV3Factory,
        [Chain.SONIC_MAINNET]: "0x777fAca731b17E8847eBF175c94DbE9d81A8f630"
    },
    codeHash: {
        default: solidlyV3InitHash
    },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "2"
}


// src/core/univ3forks/AerodromeSlipstream.sol

const aerodromeInitHash = "0xffb9af9ea6d9e39da47392ecc7055277b9915b8bfc9f83f105821b7791a6ae30"; // ERC1167 proxy
const AERODROME_SLIPSTREAM: UniswapV3Info = {
    factories: {
        [Chain.BASE]: "0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A",
    },
    codeHash: { default: aerodromeInitHash },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "5"
}

// src/core/univ3forks/AlienBaseV3.sol

const ALIENBASE_V3: UniswapV3Info = {
    factories: { [Chain.BASE]: "0x0Fd83557b2be93617c9C1C1B6fd549401C74558C" },
    codeHash: {
        default: uniswapV3InitHash
    },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "6"
};

// src/core/univ3forks/BaseX.sol

const BASEX_V3: UniswapV3Info = {
    factories: { [Chain.BASE]: "0x38015D05f4fEC8AFe15D7cc0386a126574e8077B" },
    codeHash: {
        default: uniswapV3InitHash
    },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "7"
};

// src/core/univ3forks/DackieSwapV3.sol
const DACKIESWAP_V3: UniswapV3Info = {
    factories: {
        [Chain.BASE]: "0x4f205D69834f9B101b9289F7AFFAc9B77B3fF9b7",
        [Chain.OP_MAINNET]: "0xa466ebCfa58848Feb6D8022081f1C21a884889bB",
        [Chain.ARBITRUM_ONE]: "0xf79A36F6f440392C63AD61252a64d5d3C43F860D",
        [Chain.BLAST_MAINNET]: "0x6510E68561F04C1d111e616750DaC2a063FF5055",
        [Chain.WORLD_CHAIN]: "0xc6f3966E5D08Ced98aC30f8B65BeAB5882Be54C7",
    },
    codeHash: {
        default: uniswapV3InitHash,
        [Chain.BLAST]: "0x9173e4373ab542649f2f059b10eaab2181ad82cc2e70cf51cf9d9fa8a144a2af"
    },
    callbackSelector: pancakeV3CallbackSelector,
    forkId: "1"
}


// src/core/univ3forks/KinetixV3.sol
const KINETIX_V3: UniswapV3Info = {
    factories: {
        [Chain.BASE]: "0xdDF5a3259a88Ab79D5530eB3eB14c1C92CD97FCf",
    },
    codeHash: {
        default: uniswapV3InitHash,
    },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "8"
}

const DTX: UniswapV3Info = {
    factories: {
        [Chain.TAIKO_ALETHIA]: '0xfCA1AEf282A99390B62Ca8416a68F5747716260c',
    },
    codeHash: {
        [Chain.TAIKO_ALETHIA]: uniswapV3InitHash
    },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "9"
}


// src/core/univ3forks/PancakeSwapV3.sol
const pancakeSwapV3InitHash = "0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2";
const PANCAKESWAP_V3: UniswapV3Info = {
    factories: {
        [Chain.ETHEREUM_MAINNET]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.BASE]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.ARBITRUM_ONE]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.POLYGON_ZKEVM]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.ZKSYNC_MAINNET]: "0x7f71382044A6a62595D5D357fE75CA8199123aD6",
        [Chain.LINEA]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.OPBNB_MAINNET]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
    },
    codeHash: {
        default: pancakeSwapV3InitHash,
    },
    callbackSelector: pancakeV3CallbackSelector,
    forkId: "0"
}

const PANKO_V3: UniswapV3Info = {
    factories: {
        [Chain.TAIKO_ALETHIA]: "0x7DD105453D0AEf177743F5461d7472cC779e63f7",
    },
    codeHash: {
        default: pancakeSwapV3InitHash,
    },
    callbackSelector: pancakeV3CallbackSelector,
    forkId: "1"
}

const FUSIONX_V3: UniswapV3Info = {
    factories: {
        [Chain.MANTLE]: "0x7DD105453D0AEf177743F5461d7472cC779e63f7",
    },
    codeHash: {
        default: "0x1bce652aaa6528355d7a339037433a20cd28410e3967635ba8d2ddb037440dbf",
    },
    callbackSelector: "0xae067e0f00000000000000000000000000000000000000000000000000000000",
    forkId: "0"
}

const AGNI: UniswapV3Info = {
    factories: {
        [Chain.MANTLE]: "0xe9827b4ebeb9ae41fc57efdddd79edddc2ea4d03",
    },
    codeHash: {
        default: "0x1bce652aaa6528355d7a339037433a20cd28410e3967635ba8d2ddb037440dbf",
    },
    callbackSelector: "0x5bee97a300000000000000000000000000000000000000000000000000000000",
    forkId: "0"
}

const METHLAB: UniswapV3Info = {
    factories: {
        [Chain.MANTLE]: "0x8f140fc3e9211b8dc2fc1d7ee3292f6817c5dd5d",
    },
    codeHash: {
        default: "0xacd26fbb15704ae5e5fe7342ea8ebace020e4fa5ad4a03122ce1678278cf382b",
    },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "10"
}

const QUICKSWAP: UniswapV3Info = {
    factories: {
        [Chain.POLYGON_MAINNET]: "0x2D98E2FA9da15aa6dC9581AB097Ced7af697CB92",
        [Chain.DOGECHAIN_MAINNET]: "0x56c2162254b0E4417288786eE402c2B41d4e181e",
    },
    codeHash: {
        default: "0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4",
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "0"
}

const SWAPSICLE: UniswapV3Info = {
    factories: {
        [Chain.MANTLE]: '0x9dE2dEA5c68898eb4cb2DeaFf357DFB26255a4aa',
        [Chain.TAIKO_ALETHIA]: '0xb68b27a1c93A52d698EecA5a759E2E4469432C09',
        [Chain.TELOS_EVM_MAINNET]: '0x061e47Ab9f31D293172efb88674782f80eCa88de',
    },
    codeHash: {
        [Chain.MANTLE]: '0x177d5fbf994f4d130c008797563306f1a168dc689f81b2fa23b4396931014d91',
        [Chain.TAIKO_ALETHIA]: '0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d',
        [Chain.TELOS_EVM_MAINNET]: '0x177d5fbf994f4d130c008797563306f1a168dc689f81b2fa23b4396931014d91',
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "1"
}

const HENJIN: UniswapV3Info = {
    factories: {
        [Chain.TAIKO_ALETHIA]: '0x0d22b434E478386Cd3564956BFc722073B3508f6',
    },
    codeHash: {
        [Chain.TAIKO_ALETHIA]: '0x4b9e4a8044ce5695e06fce9421a63b6f5c3db8a561eebb30ea4c775469e36eaf'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "2"
}

const CAMELOT: UniswapV3Info = {
    factories: {
        [Chain.ARBITRUM_ONE]: '0x6Dd3FB9653B10e806650F107C3B5A0a6fF974F65',
    },
    codeHash: {
        [Chain.ARBITRUM_ONE]: '0x6c1bebd370ba84753516bc1393c0d0a6c645856da55f5393ac8ab3d6dbc861d3'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "3"
}

const ATLAS: UniswapV3Info = {
    factories: {
        [Chain.HEMI_NETWORK]: '0x6b46AE0e60E0E7a2F8614b3f1dCBf6D5a0102991',
    },
    codeHash: {
        [Chain.HEMI_NETWORK]: '0xb3fc09be5eb433d99b1ec89fd8435aaf5ffea75c1879e19028aa2414a14b3c85'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "4"
}

const THENA: UniswapV3Info = {
    factories: {
        [Chain.BNB_SMART_CHAIN_MAINNET]: '0xc89F69Baa3ff17a842AB2DE89E5Fc8a8e2cc7358',
    },
    codeHash: {
        [Chain.BNB_SMART_CHAIN_MAINNET]: '0xd61302e7691f3169f5ebeca3a0a4ab8f7f998c01e55ec944e62cfb1109fd2736'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "5"
}

const ZYBERSWAP: UniswapV3Info = {
    factories: {
        [Chain.ARBITRUM_ONE]: '0x24E85F5F94C6017d2d87b434394e87df4e4D56E3',
        [Chain.OP_MAINNET]: '0xc0D4323426C709e8D04B5b130e7F059523464a91',
    },
    codeHash: {
        [Chain.ARBITRUM_ONE]: '0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4',
        [Chain.OP_MAINNET]: '0xbce37a54eab2fcd71913a0d40723e04238970e7fc1159bfd58ad5b79531697e7',
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "7"
}


const SKULLSWAP: UniswapV3Info = {
    factories: {
        [Chain.FANTOM_OPERA]: '0x630BC1372F73bf779AF5593A5a2Da68ABB3c6E55',
    },
    codeHash: {
        [Chain.FANTOM_OPERA]: '0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "8"
}

const UBESWAP: UniswapV3Info = {
    factories: {
        [Chain.CELO_MAINNET]: '0xcC980E18E3efa39e4dD98F057A432343D534314D',
    },
    codeHash: {
        [Chain.CELO_MAINNET]: '0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "9"
}


const LITX: UniswapV3Info = {
    factories: {
        [Chain.BNB_SMART_CHAIN_MAINNET]: '0x9cF85CaAC177Fb2296dcc68004e1C82A757F95ed',
    },
    codeHash: {
        [Chain.BNB_SMART_CHAIN_MAINNET]: '0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "10"
}

const STELLASWAP: UniswapV3Info = {
    factories: {
        [Chain.MOONBEAM]: '0x87a4F009f99E2F34A34A260bEa765877477c7EF9',
    },
    codeHash: {
        [Chain.MOONBEAM]: '0xb3fc09be5eb433d99b1ec89fd8435aaf5ffea75c1879e19028aa2414a14b3c85'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "11"
}

const LYNEX: UniswapV3Info = {
    factories: {
        [Chain.LINEA]: '0x9A89490F1056A7BC607EC53F93b921fE666A2C48',
    },
    codeHash: {
        [Chain.LINEA]: '0xc65e01e65f37c1ec2735556a24a9c10e4c33b2613ad486dd8209d465524bc3f4'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "12"
}


const SWAP_BASED: UniswapV3Info = {
    factories: {
        [Chain.BASE]: '0xe4DFd4ad723B5DB11aa41D53603dB03B117eC690',
    },
    codeHash: {
        [Chain.BASE]: '0xbce37a54eab2fcd71913a0d40723e04238970e7fc1159bfd58ad5b79531697e7'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "13"
}
const SYNTHSWAP: UniswapV3Info = {
    factories: {
        [Chain.BASE]: '0xBA97f8AEe67BaE3105fB4335760B103F24998a92',
    },
    codeHash: {
        [Chain.BASE]: '0xbce37a54eab2fcd71913a0d40723e04238970e7fc1159bfd58ad5b79531697e7'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "14"
}
const HERCULES: UniswapV3Info = {
    factories: {
        [Chain.METIS_ANDROMEDA_MAINNET]: '0x43AA9b2eD25F972fD8D44fDfb77a4a514eAB4d71',
    },
    codeHash: {
        [Chain.METIS_ANDROMEDA_MAINNET]: '0x6c1bebd370ba84753516bc1393c0d0a6c645856da55f5393ac8ab3d6dbc861d3'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "15"
}

const KIM: UniswapV3Info = {
    factories: {
        [Chain.MODE]: '0x6414A461B19726410E52488d9D5ff33682701635',
    },
    codeHash: {
        [Chain.MODE]: '0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "16"
}

const FENIX: UniswapV3Info = {
    factories: {
        [Chain.BLAST_MAINNET]: '0x5aCCAc55f692Ae2F065CEdDF5924C8f6B53cDaa8',
    },
    codeHash: {
        [Chain.BLAST_MAINNET]: '0xf45e886a0794c1d80aeae5ab5befecd4f0f2b77c0cf627f7c46ec92dc1fa00e4'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "17"
}

const BLADE: UniswapV3Info = {
    factories: {
        [Chain.BLAST_MAINNET]: '0xfFeEcb1fe0EAaEFeE69d122F6B7a0368637cb593',
    },
    codeHash: {
        [Chain.BLAST_MAINNET]: '0xa9df2657ce5872e94bdc9525588fd983b0aa5db2f3c7a83d7e6b6a99cd2003a1'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "18"
}
const SILVER_SWAP: UniswapV3Info = {
    factories: {
        [Chain.FANTOM_OPERA]: '0x98AF00a67F5cC0b362Da34283D7d32817F6c9A29',
    },
    codeHash: {
        [Chain.FANTOM_OPERA]: '0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "19"
}
const HORIZON: UniswapV3Info = {
    factories: {
        [Chain.LINEA]: '0xA76990a229961280200165c4e08c96Ea67304C3e',
    },
    codeHash: {
        [Chain.LINEA]: '0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "20"
}
const GLYPH: UniswapV3Info = {
    factories: {
        [Chain.CORE_BLOCKCHAIN_MAINNET]: '0x24196b3f35E1B8313016b9f6641D605dCf48A76a',
    },
    codeHash: {
        [Chain.CORE_BLOCKCHAIN_MAINNET]: '0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "21"
}
const SWAPX: UniswapV3Info = {
    factories: {
        [Chain.SONIC_MAINNET]: '0x885229E48987EA4c68F0aA1bCBff5184198A9188',
    },
    codeHash: {
        [Chain.SONIC_MAINNET]: '0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "22"
}


const BULLA: UniswapV3Info = {
    factories: {
        [Chain.BERACHAIN]: '0x425EC3de5FEB62897dbe239Aa218B2DC035DCDF1',
    },
    codeHash: {
        [Chain.BERACHAIN]: '0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "23"
}
const SCRIBE: UniswapV3Info = {
    factories: {
        [Chain.SCROLL]: '0xbAE27269D777D6fc0AefFa9DfAbA8960291E51eB',
    },
    codeHash: {
        [Chain.SCROLL]: '0x4b9e4a8044ce5695e06fce9421a63b6f5c3db8a561eebb30ea4c775469e36eaf'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "24"
}

const FIBONACCI: UniswapV3Info = {
    factories: {
        [Chain.FORM_NETWORK]: '0x1d204Ba9fceD9E5a228727Cd4Ce89620B4e4999a',
    },
    codeHash: {
        [Chain.FORM_NETWORK]: '0xb3fc09be5eb433d99b1ec89fd8435aaf5ffea75c1879e19028aa2414a14b3c85'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "25"
}
const VOLTAGE: UniswapV3Info = {
    factories: {
        [Chain.FUSE_MAINNET]: '0x9F02d3ddbC690bc65d81A98B93d449528AC4eB8C',
    },
    codeHash: {
        [Chain.FUSE_MAINNET]: '0xb3fc09be5eb433d99b1ec89fd8435aaf5ffea75c1879e19028aa2414a14b3c85'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "26"
}
const WASABEE: UniswapV3Info = {
    factories: {
        [Chain.BERACHAIN]: '0x598f320907c2FFDBC715D591ffEcC3082bA14660',
    },
    codeHash: {
        [Chain.BERACHAIN]: '0xb3fc09be5eb433d99b1ec89fd8435aaf5ffea75c1879e19028aa2414a14b3c85'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "27"
}
const HOLIVERSE: UniswapV3Info = {
    factories: {
        [Chain.POLYGON_MAINNET]: '0x0b643D3A5903ED89921b85c889797dd9887125Ad',
    },
    codeHash: {
        [Chain.POLYGON_MAINNET]: '0xb3fc09be5eb433d99b1ec89fd8435aaf5ffea75c1879e19028aa2414a14b3c85'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "28"
}
const MOR_FI: UniswapV3Info = {
    factories: {
        [Chain.MORPH]: '0xc1db2471ea7ea9227ea02f427543177d63afe44f',
    },
    codeHash: {
        [Chain.MORPH]: '0xb3fc09be5eb433d99b1ec89fd8435aaf5ffea75c1879e19028aa2414a14b3c85'
    },
    callbackSelector: algebraV3CallbackSelector,
    forkId: "29"
}

const SHADOW_CL: UniswapV3Info = {
    factories: {
        [Chain.SONIC_MAINNET]: '0x8BBDc15759a8eCf99A92E004E0C64ea9A5142d59',
    },
    codeHash: {
        [Chain.SONIC_MAINNET]: '0xc701ee63862761c31d620a4a083c61bdc1e81761e6b9c9267fd19afd22e0821d'
    },
    callbackSelector: uniswapV3CallbackSelector,
    forkId: "11"
}

const IZUMI: UniswapV3Info = {
    factories: {
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x93BB94a0d5269cb437A1F71FF3a77AB753844422",
        [Chain.ETHEREUM_MAINNET]: "0x93BB94a0d5269cb437A1F71FF3a77AB753844422",
        [Chain.MANTLE]: '0x45e5F26451CDB01B0fA1f8582E0aAD9A6F27C218',
        [Chain.POLYGON_MAINNET]: '0xcA7e21764CD8f7c1Ec40e651E25Da68AeD096037',
        [Chain.TAIKO_ALETHIA]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.ARBITRUM_ONE]: '0xCFD8A067e1fa03474e79Be646c5f6b6A27847399',
        [Chain.HEMI_NETWORK]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.METER_MAINNET]: '0xed31C5a9C764761C3A699E2732183ba5d6EAcC35',
        [Chain.ZKSYNC_MAINNET]: '0x575Bfc57B0D3eA0d31b132D622643e71735A6957',
        [Chain.ONTOLOGY_MAINNET]: '0x032b241De86a8660f1Ae0691a4760B426EA246d7',
        [Chain.LINEA]: '0x45e5F26451CDB01B0fA1f8582E0aAD9A6F27C218',
        [Chain.ETHEREUM_CLASSIC]: '0x79D175eF5fBe31b5D84B3ee359fcbBB466153E39',
        [Chain.BASE]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.OPBNB_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.KROMA]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.MANTA_PACIFIC_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.SCROLL]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.ZKFAIR_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.ZETACHAIN_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.MERLIN_MAINNET]: '0xE29a6620DAc789B8a76e9b9eC8fE9B7cf2B663D5',
        [Chain.BLAST]: '0x5162f29E9626CF7186ec40ab97D92230B428ff2d',
        [Chain.ZKLINK_NOVA_MAINNET]: '0x33D9936b7B7BC155493446B5E6dDC0350EB83AEC',
        [Chain.MODE]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.MAP_PROTOCOL]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        // [Chain.ANVN]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.X_LAYER_MAINNET]: '0xBf8F8Ef2d2a534773c61682Ea7cF5323a324B188',
        [Chain.BOB]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.KAIA_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.KAVA]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.ROOTSTOCK_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        // [Chain.CYBER]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.CORE_BLOCKCHAIN_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.NEON_EVM_MAINNET]: '0x3EF68D3f7664b2805D4E88381b64868a56f88bC4',
        [Chain.GRAVITY_ALPHA_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.EVM_ON_FLOW]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.IOTEX_NETWORK_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.MORPH]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.HASHKEY_CHAIN]: '0x110dE362cc436D7f54210f96b8C7652C2617887D',
        [Chain.PLUME_MAINNET]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
    },
    codeHash: { default: "0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40" },
    forkId: "0"
}


const BISWAP_V3: UniswapV3Info = {
    factories: {
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x7C3d53606f9c03e7f54abdDFFc3868E1C5466863",
    },
    codeHash: { default: "0x712a91d34948c3b3e0b473b519235f7d14dbf2472983bc5d3f7e67c501d7a348" },
    forkId: "1"
}


interface UniswapV3Info {
    factories: { [chain: string]: string },
    codeHash: { [chainOrDefault: string]: string },
    callbackSelector?: string,
    forkId: string,
}

export const UNISWAP_V3_FORKS: { [s: string]: UniswapV3Info } = {
    [DexProtocol.UNISWAP_V3]: UNISWAP_V3,
    [DexProtocol.SUSHISWAP_V3]: SUSHISWAP_V3,
    [DexProtocol.SOLIDLY_V3]: SOLIDLY_V3,
    [DexProtocol.PANCAKESWAP_V3]: PANCAKESWAP_V3,
    [DexProtocol.DACKIESWAP_V3]: DACKIESWAP_V3,
    [DexProtocol.ALIENBASE_V3]: ALIENBASE_V3,
    [DexProtocol.BASEX_V3]: BASEX_V3,
    [DexProtocol.KINETIX_V3]: KINETIX_V3,
    [DexProtocol.AERODROME_SLIPSTREAM]: AERODROME_SLIPSTREAM,
    [DexProtocol.QUICKSWAP_V3]: QUICKSWAP,
    [DexProtocol.HENJIN]: HENJIN,
    [DexProtocol.SWAPSICLE]: SWAPSICLE,
    [DexProtocol.AGNI]: AGNI,
    [DexProtocol.FUSIONX_V3]: FUSIONX_V3,
    [DexProtocol.METHLAB]: METHLAB,
    [DexProtocol.PANKO]: PANKO_V3,
    [DexProtocol.CAMELOT]: CAMELOT,
    [DexProtocol.DTX]: DTX,
    [DexProtocol.ATLAS]: ATLAS,
    [DexProtocol.THENA]: THENA,
    [DexProtocol.ZYBERSWAP]: ZYBERSWAP,
    [DexProtocol.SKULLSWAP]: SKULLSWAP,
    [DexProtocol.UBESWAP]: UBESWAP,
    [DexProtocol.LITX]: LITX,
    [DexProtocol.STELLASWAP]: STELLASWAP,
    [DexProtocol.LYNEX]: LYNEX,
    [DexProtocol.SWAP_BASED]: SWAP_BASED,
    [DexProtocol.SYNTHSWAP]: SYNTHSWAP,
    [DexProtocol.HERCULES]: HERCULES,
    [DexProtocol.KIM]: KIM,
    [DexProtocol.FENIX]: FENIX,
    [DexProtocol.BLADE]: BLADE,
    [DexProtocol.SILVER_SWAP]: SILVER_SWAP,
    [DexProtocol.HORIZON]: HORIZON,
    [DexProtocol.GLYPH]: GLYPH,
    [DexProtocol.SWAPX]: SWAPX,
    [DexProtocol.BULLA]: BULLA,
    [DexProtocol.SCRIBE]: SCRIBE,
    [DexProtocol.FIBONACCI]: FIBONACCI,
    [DexProtocol.VOLTAGE]: VOLTAGE,
    [DexProtocol.WASABEE]: WASABEE,
    [DexProtocol.HOLIVERSE]: HOLIVERSE,
    [DexProtocol.MOR_FI]: MOR_FI,
    [DexProtocol.SHADOW_CL]: SHADOW_CL,
}

export const IZUMI_FORKS: { [s: string]: UniswapV3Info } = {
    [DexProtocol.IZUMI]: IZUMI,
    [DexProtocol.BISWAP_V3]: BISWAP_V3,
}