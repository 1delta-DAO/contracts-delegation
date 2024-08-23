// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract AddressesEthereum {
    // assets
    
    // users
    address internal testUser = 0x5f6f935A9a69F886Dc0147904D0F455ABaC67e14;

    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    // aave type lender pool addresses
    address internal constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address internal constant SPARK_POOL = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address internal constant ZEROLEND_POOL = 0x3BC3D34C32cc98bf098D832364Df8A222bBaB4c0;
    address internal constant AVALON_POOL = 0x8AD8528202b747ED4Ab802Fd6A297c0B3CaD1cD4;
    address internal constant RADIANT_POOL = 0xA950974f64aA33f27F6C5e017eEE93BF7588ED07;
    address internal constant UWU_POOL = 0x2409aF0251DCB89EE3Dee572629291f9B087c668;
    address internal constant YLDR_POOL = 0x6447c4390457CaD03Ec1BaA4254CEe1A3D9e1Bbd;

    // compound V3 addresses
    address internal constant COMET_USDC = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address internal constant COMET_USDT = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840;
    address internal constant COMET_WETH = 0xA17581A9E3356d9A858b789D68B4d866e593aE94;

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

    uint8 DEFAULT_LENDER = 1;
    uint8 internal constant AAVE_V3 = 0;
    uint8 internal constant SPARK = 1;
    uint8 internal constant ZEROLEND = 2;
    uint8 internal constant AVALON = 25;
    uint8 internal constant RADIANT = 27;
    uint8 internal constant UWU = 26;
    uint8 internal constant YLDR = 3;

    uint8 internal constant COMET_USDC_ID = 51;
    uint8 internal constant COMET_USDT_ID = 52;
    uint8 internal constant COMET_WETH_ID = 50;

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
    uint8 internal PANCAKE_V3 = 1;
    uint8 internal SUSHI_V3 = 2;
    uint8 internal SOLIDLY_V3 = 3;
    uint8 internal CURVE = 60;
    uint8 internal CURVE_NG = 151;
    uint8 internal CURVE_META = 61;

    uint8 internal UNI_V2 = 100;
    uint8 internal SUSHI_V2 = 102;

    uint16 internal UNI_V2_FEE_DENOM = 10000 - 30;
    uint16 internal SUSHI_V2_FEE_DENOM = 10000 - 30;

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
