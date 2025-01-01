// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract AddressesArbitrum {
    // assets

    address internal WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    // users
    address internal testUser = 0x5f6f935A9a69F886Dc0147904D0F455ABaC67e14;

    address internal constant WOO_POOL = 0xEd9e3f98bBed560e66B89AaC922E29D4596A9642;

    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of upper 20 bytes.
    uint256 internal constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;

    address internal constant CRV_3_USD_AAVE_POOL = 0x445FE580eF8d70FF569aB36e80c647af338db351;
    address internal constant CRV_TRICRYPTO_ZAP = 0x1d8b86e3D88cDb2d34688e87E72F388Cb541B7C8;
    address internal constant CRV_FACTORY_ZAP = 0x3d8EADb739D1Ef95dd53D718e4810721837c69c1;
    address internal constant CRV_CRV_FACTORY_POOL = 0xc7c939A474CB10EB837894D1ed1a77C61B268Fa7;
    address internal constant CRV_TRICRYPTO_AAVE_META_POOL = 0x92215849c439E1f8612b6646060B4E3E5ef822cC;

    address internal constant CRV_NG_USDN_CRVUSD = 0x5225010A0AE133B357861782B0B865a48471b2C5;
    address internal constant crvUSD = 0xc4Ce1D6F5D98D65eE25Cf85e9F2E9DcFEe6Cb5d6;

    /** DEFAULTS */

    uint16 DEFAULT_LENDER = 1;
    uint16 AAVE_V3 = 0;
    uint16 AVALON = 1;
    uint16 YLDR = 900;


    uint16 MAX_AAVE_V2_ID = 2000;
    uint16 COMPOUND_V3_USDC = 2000;
    uint16 COMPOUND_V3_WETH = 2001;
    uint16 COMPOUND_V3_USDT = 2002;
    uint16 COMPOUND_V3_USDCE = 2003;
    
    // Flash loans
    uint8 AAVE_V3_FL = 0;
    uint8 BALANCER_V2 = 0xff;
    uint8 BALANCER_V2_DEXID = 50;

    /** DEX CONFIG */

    uint16 internal DEX_FEE_STABLES = 100;
    uint16 internal DEX_FEE_LOW_MEDIUM = 2500;
    uint16 internal DEX_FEE_LOW_HIGH = 3000;
    uint16 internal DEX_FEE_LOW = 500;
    uint16 internal DEX_FEE_NONE = 0;

    uint16 internal BIN_STEP_LOWEST = 1;
    uint16 internal BIN_STEP_LOW = 10;

    uint8 internal UNI_V3 = 0;
    uint8 internal RAMSES = 1;
    uint8 internal SUSHI_V3 = 2;
    uint8 internal ALGEBRA = 3;
    uint8 internal IZUMI = 49;

    uint8 internal CURVE = 60;
    uint8 internal CURVE_NG = 151;
    uint8 internal CURVE_META = 61;

    uint8 internal UNI_V2 = 100;
    uint8 internal CAMELOT_V2 = 101;
    uint8 internal SUSHI_V2 = 102;
    uint8 internal APESWAP = 103;

    uint16 internal UNI_V2_FEE_DENOM = 10000 - 30;
    uint16 internal CAMELOT_V2_FEE_DENOM = 10000 - 30;
    uint16 internal SUSHI_V2_FEE_DENOM = 10000 - 30;
    uint16 internal APESWAP_FEE_DENOM = 10000 - 20;

    // Solidly Stable
    uint8 internal RAMSES_V1_STABLE = 135;

    // Solidly Volatile
    uint8 internal RAMSES_V1_VOLAT = 120;

    uint8 internal WOO_FI = 150;

    /** TRADE TYPE FLAG GETTERS */

    function getOpenExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 2);
    }

    function getOpenExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 2);
    }

    function getCollateralSwapExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 3);
    }

    function getCollateralSwapExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 3);
    }

    function getCloseExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 3);
    }

    function getCloseExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 3);
    }

    function getDebtSwapExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 2);
    }

    function getDebtSwapExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 2);
    }
}
