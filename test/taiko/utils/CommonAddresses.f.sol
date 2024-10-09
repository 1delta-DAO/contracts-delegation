// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IFactoryFeeGetter {
    function getFee(bool x) external view returns (uint256);

    function getPairFee(address y, bool x) external view returns (uint256);

    function stableFee() external view returns (uint256);

    function volatileFee() external view returns (uint256);

    function pairFee(address x) external view returns (uint256);

    function getFee(address x) external view returns (uint256);

    function stable() external view returns (bool);
}

contract AddressesTaiko {
    // assets

    address internal WETH = 0xA51894664A773981C6C112C43ce576f315d5b1B6;
    address internal USDC = 0x07d83526730c7438048D55A4fc0b850e2aaB6f0b;
    address internal sgUSDC = 0x19e26B0638bf63aa9fa4d14c6baF8D52eBE86C5C;
    address internal TAIKO = 0xA9d23408b9bA935c230493c40C73824Df71A0975;
    address internal USDT = 0x2DEF195713CF4a606B49D07E520e22C17899a736;

    // users
    address internal testUser = 0xaaaa4a3F69b6DB76889bDfa4edBe1c0BB57BAA5c;

    address internal CLEO_WMNT_POOL = 0x762B916297235dc920a8c684419e41Ab0099A242;

    address veloFactory = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;

    address veloRouter = 0xCe30506F6c1Cea34aC704f93d51d55058791E497;

    bytes32 internal constant VELO_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 constant VELO_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;
    address internal constant VELO_FACOTRY = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;
    address internal constant CLEO_V1_FACOTRY = 0xAAA16c016BF556fcD620328f0759252E29b1AB57;

    bytes32 internal constant FUSION_V2_FF_FACTORY = 0xffE5020961fA51ffd3662CDf307dEf18F9a87Cce7c0000000000000000000000;
    bytes32 internal constant CODE_HASH_FUSION_V2 = 0x58c684aeb03fe49c8a3080db88e425fae262c5ef5bf0e8acffc0526c6e3c03a0;

    address internal constant MERCHANT_MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;
    address internal constant MERCHANT_MOE_LB_FACTORY = 0xa6630671775c4EA2743840F9A5016dCf2A104054;

    address internal constant KTX_VAULT = 0x2e488D7ED78171793FA91fAd5352Be423A50Dae1;
    address internal constant WOO_POOL = 0xEd9e3f98bBed560e66B89AaC922E29D4596A9642;

    address internal constant MERIDIAN_POOL = 0x1697A950a67d9040464287b88fCa6cb5FbEC09BA;
    address internal constant HANA_POOL = 0x4aB85Bf9EA548410023b25a13031E91B4c4f3b91;
    address internal constant TAKOTAKO_POOL = 0x3A2Fd8a16030fFa8D66E47C3f1C0507c673C841e;

    address internal constant MERIDIAN_A_TAIKO = 0xc2aB0FE37dB900ed7b7d3E0bc6a194cB78E33FB4;
    address internal constant MERIDIAN_A_USDC = 0x3807A7D65D82784E91Fb4eaD75044C7B4F03A462;
    address internal constant MERIDIAN_A_WETH = 0xB908808F52116380FFADCaebcab97A8cAD9409D2;

    address internal constant MERIDIAN_V_TAIKO = 0xce0f8615380843EFa8CF6650a712c05e534A0e3F;
    address internal constant MERIDIAN_V_USDC = 0xd37B96C82D4540610017126c042AFdde28578Afa;
    address internal constant MERIDIAN_V_WETH = 0x3Ef9b96D8a88Df1CAAB4A060e2904Fe26aE518Ce;

    address internal constant MERIDIAN_S_TAIKO = address(0);
    address internal constant MERIDIAN_S_USDC = address(0);
    address internal constant MERIDIAN_S_WETH = address(0);

    address internal constant HANA_A_TAIKO = 0x67F1E0A9c9D540F61D50B974DBd63aABf636a296;
    address internal constant HANA_A_USDC = 0x5C9bC967E338F48535c3DF7f80F2DB0A366D36b2;
    address internal constant HANA_A_WETH = 0xacd2E13C933aE1EF97698f00D14117BB70C77Ef1;

    address internal constant HANA_V_TAIKO = 0x1592Ff6f057d65a17Be56116e2B3cbfD4d2314C2;
    address internal constant HANA_V_USDC = 0x0247606c3D3F62213bbC9D7373318369e6860eb1;
    address internal constant HANA_V_WETH = 0xf1777EAD4098F574c68E59905588f3C9875251ed;

    address internal constant HANA_S_TAIKO = address(0);
    address internal constant HANA_S_USDC = address(0);
    address internal constant HANA_S_WETH = address(0);

    address internal constant TAKOTAKO_A_TAIKO = 0xbbFa45a92d9d071554B59D2d29174584D9b06bc3;
    address internal constant TAKOTAKO_A_USDC = 0x79a741EBFE9c323CF63180c405c050cdD98c21d8;
    address internal constant TAKOTAKO_A_WETH = 0x6Afa285ab05657f7102F66F1B384347aEF3Ef6Aa;

    address internal constant TAKOTAKO_V_TAIKO = 0x0f0244337f1215E6D8e13Af1b5ae639244d8a6f6;
    address internal constant TAKOTAKO_V_USDC = 0x72C6bDf69952b6bc8aCc18c178d9E03EAc5eaD50;
    address internal constant TAKOTAKO_V_WETH = 0x19871b9911ddbd422e06F66427768f9B65d36F81;

    address internal constant TAKOTAKO_S_TAIKO = address(0);
    address internal constant TAKOTAKO_S_USDC = address(0);
    address internal constant TAKOTAKO_S_WETH = address(0);

    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of upper 20 bytes.
    uint256 internal constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;

    /** DEFAULTS */

    uint8 HANA_ID = 0;
    uint8 MERIDIAN_ID = 1;
    uint8 TAKOTAKO_ID = 2;

    /** DEX CONFIG */

    uint16 internal DEX_FEE_STABLES = 100;
    uint16 internal DEX_FEE_LOW_MEDIUM = 2500;
    uint16 internal DEX_FEE_LOW_HIGH = 3000;
    uint16 internal DEX_FEE_LOW = 500;
    uint16 internal DEX_FEE_NONE = 0;

    uint16 internal BIN_STEP_LOWEST = 1;
    uint16 internal BIN_STEP_LOW = 10;

    uint8 internal AGNI = 1;
    uint8 internal DTX = 1;
    uint8 internal UNI_V3 = 0;
    uint8 internal BUTTER = 3;
    uint8 internal CLEOPATRA_CL = 4;
    uint8 internal IZUMI = 49;
    uint8 internal STRATUM_CURVE = 51;
    uint8 internal STRATUM_USD = 50;

    uint8 internal FUSION_X_V2 = 100;
    uint8 internal MERCHANT_MOE = 101;
    // Solidly STable
    uint8 internal CLEO_V1_STABLE = 135;
    uint8 internal KODO_STABLE = 135;
    uint8 internal STRATUM_STABLE = 136;
    uint8 internal VELO_STABLE = 137;

    // Solidly Volatile
    uint8 internal CLEO_V1_VOLAT = 120;
    uint8 internal KODO_VOLAT = 120;
    uint8 internal STRATUM_VOLAT = 121;
    uint8 internal VELO_VOLAT = 122;

    uint16 internal KODO_VOLAT_FEE_DENOM = 10000 - 20;
    uint16 internal KODO_STABLE_FEE_DENOM = 10000 - 2;

    uint16 internal FUSION_X_V2_FEE_DENOM = 10000 - 20;
    uint16 internal MERCHANT_MOE_FEE_DENOM = 10000 - 30;
    uint16 internal BASE_DENOM = 10000;

    function getV2PairFeeDenom(uint8 fork, address pool) internal view returns (uint16) {
        if (fork == FUSION_X_V2) return FUSION_X_V2_FEE_DENOM;
        if (fork == MERCHANT_MOE) return MERCHANT_MOE_FEE_DENOM;
        if (fork == CLEO_V1_STABLE) {
            uint16 pairFee = uint16(IFactoryFeeGetter(CLEO_V1_FACOTRY).pairFee(pool));
            if (pairFee == 0) pairFee = uint16(IFactoryFeeGetter(CLEO_V1_FACOTRY).stableFee());
            return 10000 - pairFee;
        }
        if (fork == CLEO_V1_VOLAT) {
            uint16 pairFee = uint16(IFactoryFeeGetter(CLEO_V1_FACOTRY).pairFee(pool));
            if (pairFee == 0) pairFee = uint16(IFactoryFeeGetter(CLEO_V1_FACOTRY).volatileFee());
            return 10000 - pairFee;
        }
        if (fork == VELO_STABLE || fork == VELO_VOLAT) {
            uint16 pairFee = uint16(IFactoryFeeGetter(VELO_FACOTRY).pairFee(pool));
            return 10000 - pairFee;
        }
        return 0;
    }

    // exotic
    uint8 internal MERCHANT_MOE_LB = 151;
    uint8 internal WOO_FI = 150;
    uint8 internal KTX = 152;

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
