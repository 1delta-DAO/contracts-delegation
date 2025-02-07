// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

interface ISyncSwapFactory {
    function getPool(address, address) external view returns (address);
}

/**
 * Quoter contract
 * Paths have to be encoded as follows: token0 (address) | param0 (uint24) | poolId (uint8) | token1 (address) |
 */
contract PoolGetter {
    error invalidDexId();

    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal immutable MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal immutable MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

    // _FF_ is given as follows: bytes32((uint256(0xff) << 248) | (uint256(uint160(address)) << 88));

    // v3s

    bytes32 internal constant IZI_FF_FACTORY = 0xff8c7d3063579BdB0b90997e18A770eaE32E1eBb080000000000000000000000;
    bytes32 internal constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    // henjin
    bytes32 internal constant ALGEBRA_V3_FF_DEPLOYER = 0xff0d22b434E478386Cd3564956BFc722073B3508f60000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_INIT_CODE_HASH = 0x4b9e4a8044ce5695e06fce9421a63b6f5c3db8a561eebb30ea4c775469e36eaf;
    // SwapSicle
    bytes32 internal constant ALGEBRA_V3_SS_FF_DEPLOYER = 0xffb68b27a1c93A52d698EecA5a759E2E4469432C090000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_SS_INIT_CODE_HASH = 0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d;

    bytes32 internal constant DTX_FF_FACTORY = 0xfffCA1AEf282A99390B62Ca8416a68F5747716260c0000000000000000000000;
    bytes32 internal constant DTX_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant UNISWAP_V3_FF_FACTORY = 0xff75FC67473A91335B5b8F8821277262a13B38c9b30000000000000000000000;
    bytes32 internal constant UNISWAP_V3_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant PANKO_FF_FACTORY = 0xff7DD105453D0AEf177743F5461d7472cC779e63f70000000000000000000000;
    bytes32 internal constant PANKO_INIT_CODE_HASH = 0x72390f3f9e3d8044b0b3a9836ba01a85bb91416ad47a08360a78788e9602bd5e;

    // v2s

    bytes32 internal constant DTX_UNI_V2_FF_FACTORY = 0xff2ea9051d5a48ea2350b26306f2b959d262cf67e10000000000000000000000;
    bytes32 internal constant CODE_HASH_DTX_UNI_V2 = 0x8615843ab28b4b86b2382dca22cf14f0a6ba9e52cb006531eb574042a5b54a46;

    bytes32 internal constant KODO_FF_FACTORY = 0xff535E02960574d8155596a73c7Ad66e87e37Eb6Bc0000000000000000000000;
    bytes32 constant KODO_CODE_HASH = 0x24364b5d47cc9af524ff2ae89d98c1c10f4a388556279eecb00622b5d727c99a;

    // ritsu
    address internal constant RITSU_CLASSIC_FACTORY = 0x0A78CAB89a069555a18B78537f09fab24c03dECd;
    address internal constant RITSU_STABLE_FACTORY = 0x3e846B1520E74728EFf445F1f86D348755F738d9;
    address internal constant RITSU_BASE_FACTORY = 0xDFFee0ad5C833f2A5E610dfe9FD1aD82743eA74e;

    /// @dev Returns the pool for the given token pair and fee.
    /// The pool contract may or may not exist.
    function v3TypePool(address tokenA, address tokenB, uint24 fee, uint256 _pId) external pure returns (address pool) {
        assembly {
            let s := mload(0x40)
            let p := s
            switch _pId
            // Uni
            case 0 {
                mstore(p, UNISWAP_V3_FF_FACTORY)
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
                mstore(p, UNISWAP_V3_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            case 3 {
                mstore(p, PANKO_FF_FACTORY)
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
                mstore(p, PANKO_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            case 1 {
                mstore(p, DTX_FF_FACTORY)
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
                mstore(p, DTX_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Algebra / Swapsicle
            case 2 {
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
            // Algebra / Swapsicle
            case 5 {
                mstore(p, ALGEBRA_V3_SS_FF_DEPLOYER)
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
                mstore(p, ALGEBRA_POOL_SS_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            case 49 {
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
            default {
                revert(0, 0)
            }
        }
    }

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getiZiPool(address tokenA, address tokenB, uint24 fee) external pure returns (address pool) {
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
    function v2TypePairAddress(address tokenA, address tokenB, uint256 _pId) external pure returns (address pair) {
        assembly {
            switch _pId
            // DTX V1
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
                mstore(0xB00, DTX_UNI_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_DTX_UNI_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // KODO Volatile
            case 120 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 0)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, KODO_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, KODO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // KODO Stable
            case 135 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 1)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, KODO_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, KODO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            default {
                revert(0, 0)
            }
        }
    }

    function syncClassicPairAddress(address tokenA, address tokenB) external view returns (address pair) {
        pair = ISyncSwapFactory(RITSU_CLASSIC_FACTORY).getPool(tokenA, tokenB);
    }

    function syncStablePairAddress(address tokenA, address tokenB) external view returns (address pair) {
        pair = ISyncSwapFactory(RITSU_STABLE_FACTORY).getPool(tokenA, tokenB);
    }

    function syncBasePairAddress(address tokenA, address tokenB) external view returns (address pair) {
        pair = ISyncSwapFactory(RITSU_BASE_FACTORY).getPool(tokenA, tokenB);
    }
}
