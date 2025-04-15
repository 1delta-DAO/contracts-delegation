// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract AddressesPolygon {
    // users
    address internal testUser = 0x5f6f935A9a69F886Dc0147904D0F455ABaC67e14;

    address internal constant WOO_POOL = 0xEd9e3f98bBed560e66B89AaC922E29D4596A9642;

    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    address internal constant CRV_4_EUR = 0xAd326c253A84e9805559b73A08724e11E49ca651;
    address internal constant CRV_3_USD_AAVE_POOL = 0x445FE580eF8d70FF569aB36e80c647af338db351;
    address internal constant CRV_TRICRYPTO_ZAP = 0x1d8b86e3D88cDb2d34688e87E72F388Cb541B7C8;
    address internal constant CRV_FACTORY_ZAP = 0x3d8EADb739D1Ef95dd53D718e4810721837c69c1;
    address internal constant CRV_CRV_FACTORY_POOL = 0xc7c939A474CB10EB837894D1ed1a77C61B268Fa7;
    address internal constant CRV_TRICRYPTO_AAVE_META_POOL = 0x92215849c439E1f8612b6646060B4E3E5ef822cC;

    address internal constant CRV_NG_USDN_CRVUSD = 0x5225010A0AE133B357861782B0B865a48471b2C5;

    /**
     * DEX CONFIG
     */
    uint16 internal DEX_FEE_STABLES = 100;
    uint16 internal DEX_FEE_LOW_MEDIUM = 2500;
    uint16 internal DEX_FEE_LOW_HIGH = 3000;
    uint16 internal DEX_FEE_LOW = 500;
    uint16 internal DEX_FEE_NONE = 0;

    uint16 internal UNI_V2_FEE_DENOM = 10000 - 30;
    uint16 internal QUICK_V2_FEE_DENOM = 10000 - 30;
    uint16 internal SUSHI_V2_FEE_DENOM = 10000 - 30;
    uint16 internal DFYN_FEE_DENOM = 10000 - 30;
    uint16 internal POLYCAT_FEE_DENOM = 10000 - 24;
    uint16 internal APESWAP_FEE_DENOM = 10000 - 20;
    uint16 internal COMETH_FEE_DENOM = 10000 - 50;

    uint8 internal WOO_FI = 150;

    /**
     * TRADE TYPE FLAG GETTERS
     */
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
