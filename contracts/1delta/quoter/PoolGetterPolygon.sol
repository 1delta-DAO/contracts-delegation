// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.26;

/**
 * Quoter contract
 * Paths have to be encoded as follows: token0 (address) | param0 (uint24) | poolId (uint8) | token1 (address) |
 */
abstract contract PoolGetterPolygon {
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

    bytes32 internal constant SMARDEX_FF_FACTORY = 0xff9A1e1681f6D59Ca051776410465AfAda6384398f0000000000000000000000;
    bytes32 internal constant CODE_HASH_SMARDEX = 0x33bee911475f015247aeb1eebe149d1c6d2669be54126c29d85df6b0abb4c4e9;

    bytes32 internal constant UNI_V3_FF_FACTORY = 0xff1f98431c8ad98523631ae4a59f267346ea31f9840000000000000000000000;
    bytes32 internal constant UNI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant RETRO_FF_FACTORY = 0xffe9827B4EBeB9AE41FC57efDdDd79EDddC2EA4d030000000000000000000000;
    bytes32 internal constant RETRO_POOL_INIT_CODE_HASH = 0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a;

    bytes32 internal constant IZI_FF_FACTORY = 0xffcA7e21764CD8f7c1Ec40e651E25Da68AeD0960370000000000000000000000;
    bytes32 internal constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    bytes32 internal constant ALGEBRA_V3_FF_DEPLOYER = 0xff2d98e2fa9da15aa6dc9581ab097ced7af697cb920000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_INIT_CODE_HASH = 0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4;

    bytes32 internal constant SUSHI_V3_FF_DEPLOYER = 0xff917933899c6a5F8E37F31E19f92CdBFF7e8FF0e20000000000000000000000;
    bytes32 internal constant SUSHI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    address internal constant MERCHANT_MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;
    address internal constant MERCHANT_MOE_LB_FACTORY = 0xa6630671775c4EA2743840F9A5016dCf2A104054;

    bytes32 internal constant METHLAB_FF_FACTORY = 0xff8f140fc3e9211b8dc2fc1d7ee3292f6817c5dd5d0000000000000000000000;
    bytes32 internal constant METHLAB_INIT_CODE_HASH = 0xacd26fbb15704ae5e5fe7342ea8ebace020e4fa5ad4a03122ce1678278cf382b;

    bytes32 internal constant VELO_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 constant VELO_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;
    address internal constant VELO_FACTORY = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;

    bytes32 internal constant CLEO_V1_FF_FACTORY = 0xffAAA16c016BF556fcD620328f0759252E29b1AB570000000000000000000000;
    bytes32 constant CLEO_V1_CODE_HASH = 0xbf2404274de2b11f05e5aebd49e508de933034cb5fa2d0ac3de8cbd4bcef47dc;
    address internal constant CLEO_V1_FACTORY = 0xAAA16c016BF556fcD620328f0759252E29b1AB57;

    bytes32 internal constant STRATUM_FF_FACTORY = 0xff061FFE84B0F9E1669A6bf24548E5390DBf1e03b20000000000000000000000;
    bytes32 constant STRATUM_CODE_HASH = 0xeb675862e19b0846fd47f7db0e8f2bf8f8da0dcd0c9aa75603248566f3faa805;
    address internal constant STRATUM_FACTORY = 0x061FFE84B0F9E1669A6bf24548E5390DBf1e03b2;

    address internal constant WOO_ROUTER = 0x4c4AF8DBc524681930a27b2F1Af5bcC8062E6fB7;

    address internal constant KTX_VAULT = 0x2e488D7ED78171793FA91fAd5352Be423A50Dae1;
    address internal constant KTX_VAULT_UTILS = 0x25e71a6b45598213E95F9a718e3FE0523e9d9E34;
    address internal constant KTX_VAULT_PRICE_FEED = 0xEdd1E8aACF7652aD8c015C4A403A9aE36F3Fe4B7;
    address internal constant USDG = 0x1Ca85898619cF01eDD8bE6ef7f8989da03D6B694;
    uint256 internal constant PRICE_PRECISION = 10 ** 30;

    bytes32 internal constant QUICK_V2_FF_FACTORY = 0xff5757371414417b8c6caad45baef941abc7d3ab320000000000000000000000;
 
    bytes32 internal constant UNI_V2_FF_FACTORY = 0xff9e5A52f57b3038F1B8EeE45F28b3C1967e22799C0000000000000000000000;
    bytes32 internal constant CODE_HASH_UNI_V2 = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 internal constant FRAX_SWAP_FF_FACTORY = 0xff54F454D747e037Da288dB568D4121117EAb34e790000000000000000000000;
    bytes32 internal constant CODE_HASH_FRAX_SWAP = 0x4ce0b4ab368f39e4bd03ec712dfc405eb5a36cdb0294b3887b441cd1c743ced3;

    bytes32 internal constant SUSHI_V2_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
    bytes32 internal constant CODE_HASH_SUSHI_V2 = 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303;
 
    bytes32 internal constant DFYN_FF_FACTORY = 0xffE7Fb3e833eFE5F9c441105EB65Ef8b261266423B0000000000000000000000;
    bytes32 internal constant CODE_HASH_DFYN = 0xf187ed688403aa4f7acfada758d8d53698753b998a3071b06f1b777f4330eaf3;

    /// @dev Returns the pool for the given token pair and fee.
    /// The pool contract may or may not exist.
    function v3TypePool(address tokenA, address tokenB, uint24 fee, uint256 _pId) internal pure returns (address pool) {
        assembly {
            let s := mload(0x40)
            let p := s
            switch _pId
            // FusionX
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
            // Agni
            case 1 {
                mstore(p, RETRO_FF_FACTORY)
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
                mstore(p, RETRO_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Algebra / QUickswap V3
            case 3 {
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
            // Butter
            case 2 {
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
            // MethLab
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
    function v2TypePairAddress(address tokenA, address tokenB, uint256 _pId) internal pure returns (address pair) {
        assembly {
            switch _pId
            // Uni
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
            // 101: Quick
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
                mstore(0xB00, QUICK_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_UNI_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Sushi
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
                mstore(0xB00, SUSHI_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_SUSHI_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // DFYN
            case 103 {
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
                mstore(0xB00, DFYN_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_DFYN)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
        }
    }
}
