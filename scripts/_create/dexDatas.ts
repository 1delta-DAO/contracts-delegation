import { Chain } from "@1delta/asset-registry";
import { DexProtocol } from "./dexs";


const UNISWAP_V4_PM = {
    [Chain.ETHEREUM_MAINNET]: "0x000000000004444c5dc75cB358380D2e3dE08A90",
    [Chain.ARBITRUM_ONE]: "0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32",
    [Chain.AVALANCHE_C_CHAIN]: "0x06380C0e0912312B5150364B9DC4542BA0DbBc85",
    [Chain.BASE]: "0x498581fF718922c3f8e6A244956aF099B2652b2b",
    [Chain.BLAST]: "0x1631559198A9e474033433b2958daBC135ab6446",
    [Chain.BNB_SMART_CHAIN_MAINNET]: "0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF",
    [Chain.OP_MAINNET]: "0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3",
    [Chain.POLYGON_MAINNET]: "0x67366782805870060151383F4BbFF9daB53e5cD6",
    [Chain.WORLD_CHAIN]: "0xb1860D529182ac3BC1F51Fa2ABd56662b7D13f33",
}

const uniswapV3InitHash = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";

const UNISWAP_V3 = {
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
        [Chain.HEMI_NETWORK]: "0x346239972d1fa486FC4a521031BC81bFB7D6e8a4"
    },
    codeHash: { default: uniswapV3InitHash }
}

const SUSHISWAP_V3 = {
    factories: {
        [Chain.ETHEREUM_MAINNET]: "0xbACEB8eC6b9355Dfc0269C18bac9d6E2Bdc29C4F",
        [Chain.BASE]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4", // Base, Linea
        [Chain.LINEA]: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4", // Base, Linea
        [Chain.ARBITRUM_ONE]: "0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e",
        [Chain.AVALANCHE_C_CHAIN]: "0x3e603C14aF37EBdaD31709C4f848Fc6aD5BEc715",
        [Chain.BLAST_MAINNET]: "0x7680D4B43f3d1d54d6cfEeB2169463bFa7a6cf0d",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x126555dd55a39328F69400d6aE4F782Bd4C34ABb",
        [Chain.OP_MAINNET]: "0x9c6522117e2ed1fE5bdb72bb0eD5E3f2bdE7DBe0",
        [Chain.POLYGON_MAINNET]: "0x917933899c6a5F8E37F31E19f92CdBFF7e8FF0e2",
        [Chain.SCROLL]: "0x46B3fDF7b5CDe91Ac049936bF0bDb12c5d22202e",
        [Chain.GNOSIS]: "0xf78031CBCA409F2FB6876BDFDBc1b2df24cF9bEf",
        [Chain.HEMI_NETWORK]: '0xCdBCd51a5E8728E0AF4895ce5771b7d17fF71959',
    },
    codeHash: {
        default: uniswapV3InitHash,
        [Chain.BLAST]: "0x8e13daee7f5a62e37e71bf852bcd44e7d16b90617ed2b17c24c2ee62411c5bae",
    }
}

const solidlyV3Factory = "0x70Fe4a44EA505cFa3A57b95cF2862D4fd5F0f687"
const solidlyV3InitHash = "0xe9b68c5f77858eecac2e651646e208175e9b1359d68d0e14fc69f8c54e5010bf";

const SOLIDLY_V3 = {
    factories: {
        [Chain.ETHEREUM_MAINNET]: solidlyV3Factory,
        [Chain.BASE]: solidlyV3Factory,
        [Chain.SONIC_MAINNET]: "0x777fAca731b17E8847eBF175c94DbE9d81A8f630"
    },
    codeHash: {
        default: solidlyV3InitHash
    }

}


// src/core/univ3forks/AerodromeSlipstream.sol

const aerodromeInitHash = "0xffb9af9ea6d9e39da47392ecc7055277b9915b8bfc9f83f105821b7791a6ae30"; // ERC1167 proxy
const AERODROME_V3 = {
    factories: {
        [Chain.BASE]: "0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A",
    },
    codeHash: { default: aerodromeInitHash }
}

// src/core/univ3forks/AlienBaseV3.sol

const ALIENBASE_V3 = {
    factories: { [Chain.BASE]: "0x0Fd83557b2be93617c9C1C1B6fd549401C74558C" },
    codeHash: {
        default: uniswapV3InitHash
    }
};

// src/core/univ3forks/BaseX.sol

const BASEX_V3 = {
    factories: { [Chain.BASE]: "0x38015D05f4fEC8AFe15D7cc0386a126574e8077B" },
    codeHash: {
        default: uniswapV3InitHash
    }
};

// src/core/univ3forks/DackieSwapV3.sol
const DACKIESWAP_V3 = {
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
    }
}


// src/core/univ3forks/KinetixV3.sol
const KINETIX_V3 = {
    factories: {
        [Chain.BASE]: "0xdDF5a3259a88Ab79D5530eB3eB14c1C92CD97FCf",
    },
    codeHash: {
        default: uniswapV3InitHash,
    }
}


// src/core/univ3forks/PancakeSwapV3.sol
const pancakeSwapV3InitHash = "0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2";
const PANCAKESWAP_V3 = {
    factories: {
        [Chain.ETHEREUM_MAINNET]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.BASE]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.ARBITRUM_ONE]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.POLYGON_ZKEVM]: "0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9",
        [Chain.ZKSYNC_MAINNET]: "0x7f71382044A6a62595D5D357fE75CA8199123aD6",
    },
    codeHash: {
        default: pancakeSwapV3InitHash,
    }
}


const MAVERICK_V2 = {
    codeHash: { default: "0xbb7b783eb4b8ca46925c5384a6b9919df57cb83da8f76e37291f58d0dd5c439a" },

    // https://docs.mav.xyz/technical-reference/contract-addresses/v2-contract-addresses
    // For chains: mainnet, base, bnb, arbitrum, scroll, sepolia
    factories: {
        [Chain.ETHEREUM_MAINNET]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e",
        [Chain.BASE]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e",
        [Chain.ARBITRUM_ONE]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e",
        [Chain.SCROLL]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e"
    }
}

const IZUMI = {
    factories: {
        [Chain.MANTLE]: '0x45e5F26451CDB01B0fA1f8582E0aAD9A6F27C218',
        [Chain.POLYGON_MAINNET]: '0xcA7e21764CD8f7c1Ec40e651E25Da68AeD096037',
        [Chain.TAIKO_ALETHIA]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
        [Chain.ARBITRUM_ONE]: '0xCFD8A067e1fa03474e79Be646c5f6b6A27847399',
        [Chain.HEMI_NETWORK]: '0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08',
    },
    codeHash: { default: "0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40" }
}


interface UniswapV3Info {
    factories: { [chain: string]: string },
    codeHash: { [chainOrDefault: string]: string },
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
}

export const IZUMI_FORKS: { [s: string]: UniswapV3Info } = {
    [DexProtocol.IZUMI]: IZUMI
}