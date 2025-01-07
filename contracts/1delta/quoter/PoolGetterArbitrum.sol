// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

/**
 * Quoter contract
 * Paths have to be encoded as follows: token0 (address) | param0 (uint24) | poolId (uint8) | token1 (address) |
 */
abstract contract PoolGetterArbitrum {
    error invalidDexId();

    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;
    /// @dev Mask of lower 1 byte.
    uint256 internal constant UINT8_MASK = 0xff;
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal immutable MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal immutable MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

    // _FF_ is given as follows: bytes32((uint256(0xff) << 248) | (uint256(uint160(address)) << 88));

    // v3s

    bytes32 internal constant UNI_V3_FF_FACTORY = 0xff1f98431c8ad98523631ae4a59f267346ea31f9840000000000000000000000;
    bytes32 internal constant UNI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant RAMSES_FF_FACTORY = 0xffAA2cd7477c451E703f3B9Ba5663334914763edF80000000000000000000000;
    bytes32 internal constant RAMSES_POOL_INIT_CODE_HASH = 0x1565b129f2d1790f12d45301b9b084335626f0c92410bc43130763b69971135d;

    bytes32 internal constant IZI_FF_FACTORY = 0xffCFD8A067e1fa03474e79Be646c5f6b6A278473990000000000000000000000;
    bytes32 internal constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    bytes32 internal constant ALGEBRA_V3_FF_DEPLOYER = 0xff6Dd3FB9653B10e806650F107C3B5A0a6fF974F650000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_INIT_CODE_HASH = 0x6c1bebd370ba84753516bc1393c0d0a6c645856da55f5393ac8ab3d6dbc861d3;

    bytes32 internal constant SUSHI_V3_FF_DEPLOYER = 0xff1af415a1EbA07a4986a52B6f2e7dE7003D82231e0000000000000000000000;
    bytes32 internal constant SUSHI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant PANCAKE_FF_FACTORY = 0xff41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c90000000000000000000000;
    bytes32 internal constant PANCAKE_INIT_CODE_HASH = 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;

    // v2s

    bytes32 internal constant UNI_V2_FF_FACTORY = 0xff5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f0000000000000000000000;
    bytes32 internal constant CODE_HASH_UNI_V2 = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 internal constant FRAX_SWAP_FF_FACTORY = 0xff8374A74A728f06bEa6B7259C68AA7BBB732bfeaD0000000000000000000000;
    bytes32 internal constant CODE_HASH_FRAX_SWAP = 0x46dd19aa7d926c9d41df47574e3c09b978a1572918da0e3da18ad785c1621d48;

    bytes32 internal constant SUSHI_V2_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
    bytes32 internal constant CODE_HASH_SUSHI_V2 = 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303;

    bytes32 internal constant CAMELOT_V2_FF_FACTORY = 0xff6EcCab422D763aC031210895C81787E87B43A6520000000000000000000000;
    bytes32 internal constant CODE_HASH_CAMELOT_V2 = 0xa856464ae65f7619087bc369daaf7e387dae1e5af69cfa7935850ebf754b04c1;

    bytes32 internal constant APESWAP_FF_FACTORY = 0xffCf083Be4164828f00cAE704EC15a36D7114912840000000000000000000000;
    bytes32 internal constant CODE_HASH_APESWAP = 0xae7373e804a043c4c08107a81def627eeb3792e211fb4711fcfe32f0e4c45fd5;

    address internal constant RAMSES_V1_FACTORY = 0xAA9B8a7430474119A442ef0C2Bf88f7c3c776F2F;

    address internal constant WOO_ROUTER = 0x4c4AF8DBc524681930a27b2F1Af5bcC8062E6fB7;

    address internal constant KTX_VAULT = 0xc657A1440d266dD21ec3c299A8B9098065f663Bb;
    address internal constant KTX_VAULT_UTILS = 0xbde9c699e719bb44811252FDb3B37E6D3eDa5a28;
    address internal constant KTX_VAULT_PRICE_FEED = 0x28403B8668Db61De7484A2EAafB65b950a21a2fb;

    address internal constant USDG = 0x01F28e368dFd0ef184eDA005142650d0B877d645;

    uint256 internal constant PRICE_PRECISION = 10 ** 30;

    /// @dev Returns the pool for the given token pair and fee.
    /// The pool contract may or may not exist.
    function v3TypePool(address tokenA, address tokenB, uint24 fee, uint256 _pId) internal pure returns (address pool) {
        assembly {
            let s := mload(0x40)
            let p := s
            switch _pId
            // Uniswap
            case 0 {
                mstore(p, UNI_V3_FF_FACTORY)
                p := add(p, 21)
                // Compute the inner hash in-place
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(p, tokenB)
                    mstore(add(p, 32), tokenA)
                }
                default {
                    mstore(p, tokenA)
                    mstore(add(p, 32), tokenB)
                }
                mstore(add(p, 64), and(UINT24_MASK, fee))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, UNI_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Sushi
            case 1 {
                mstore(p, SUSHI_V3_FF_DEPLOYER)
                p := add(p, 21)
                // Compute the inner hash in-place
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(p, tokenB)
                    mstore(add(p, 32), tokenA)
                }
                default {
                    mstore(p, tokenA)
                    mstore(add(p, 32), tokenB)
                }
                mstore(add(p, 64), and(UINT24_MASK, fee))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, SUSHI_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Algebra / Camelot
            case 4 {
                mstore(p, ALGEBRA_V3_FF_DEPLOYER)
                p := add(p, 21)
                // Compute the inner hash in-place
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(p, tokenB)
                    mstore(add(p, 32), tokenA)
                }
                default {
                    mstore(p, tokenA)
                    mstore(add(p, 32), tokenB)
                }
                mstore(p, keccak256(p, 64))
                p := add(p, 32)
                mstore(p, ALGEBRA_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Pancake
            case 2 {
                mstore(p, PANCAKE_FF_FACTORY)
                p := add(p, 21)
                // Compute the inner hash in-place
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(p, tokenB)
                    mstore(add(p, 32), tokenA)
                }
                default {
                    mstore(p, tokenA)
                    mstore(add(p, 32), tokenB)
                }
                mstore(add(p, 64), and(UINT24_MASK, fee))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, PANCAKE_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Ramses
            case 3 {
                mstore(p, RAMSES_FF_FACTORY)
                p := add(p, 21)
                // Compute the inner hash in-place
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(p, tokenB)
                    mstore(add(p, 32), tokenA)
                }
                default {
                    mstore(p, tokenA)
                    mstore(add(p, 32), tokenB)
                }
                mstore(add(p, 64), and(UINT24_MASK, fee))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, RAMSES_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            default {
                revert(0, 0)
            }
        }
    }

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getiZiPool(address tokenA, address tokenB, uint24 fee) internal pure returns (address pool) {
        assembly {
            let s := mload(0x40)
            let p := s
            mstore(p, IZI_FF_FACTORY)
            p := add(p, 21)
            switch lt(tokenA, tokenB)
            case 0 {
                mstore(p, tokenB)
                mstore(add(p, 32), tokenA)
            }
            default {
                mstore(p, tokenA)
                mstore(add(p, 32), tokenB)
            }
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, IZI_POOL_INIT_CODE_HASH)
            pool := and(ADDRESS_MASK, keccak256(s, 85))
        }
    }

    /// @dev gets uniswapV2 (and fork) pair addresses
    function v2TypePairAddress(address tokenA, address tokenB, uint256 _pId) internal view returns (address pair) {
        assembly {
            switch _pId
            // Uno
            case 100 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                let salt := keccak256(0xB0C, 0x28)
                mstore(0xB00, UNI_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_UNI_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // 101: Sushi
            case 101 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                let salt := keccak256(0xB0C, 0x28)
                mstore(0xB00, SUSHI_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_SUSHI_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // 102: Apeswap
            case 102 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                let salt := keccak256(0xB0C, 0x28)
                mstore(0xB00, APESWAP_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_APESWAP)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Ramses V1 Volatile
            case 120 {
                let ptr := mload(0x40)
                // selector for getPair(address,address,bool)
                mstore(ptr, 0x6801cc3000000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), tokenA)
                mstore(add(ptr, 0x24), tokenB)
                mstore(add(ptr, 0x34), 0)
                // get pair from factory
                pop(staticcall(gas(), RAMSES_V1_FACTORY, ptr, 0x48, ptr, 0x20))
                pair := mload(ptr)
            }
            // Ramses V1 Stable
            case 135 {
                let ptr := mload(0x40)
                // selector for getPair(address,address,bool)
                mstore(ptr, 0x6801cc3000000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x4), tokenA)
                mstore(add(ptr, 0x24), tokenB)
                mstore(add(ptr, 0x34), 1)
                // get pair from factory
                pop(staticcall(gas(), RAMSES_V1_FACTORY, ptr, 0x48, ptr, 0x20))
                pair := mload(ptr)
            }
            // Camelot V2 Volatile
            case 121 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                let salt := keccak256(0xB0C, 0x28)
                mstore(0xB00, CAMELOT_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_CAMELOT_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Camelot V2 Stable
            case 136 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                let salt := keccak256(0xB0C, 0x28)
                mstore(0xB00, CAMELOT_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_CAMELOT_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // none
            default {
                revert(0, 0)
            }
        }
    }
}
