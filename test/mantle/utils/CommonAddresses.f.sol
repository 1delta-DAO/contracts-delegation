// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {DexMappingsMantle} from "./DexMappings.sol";

interface IFactoryFeeGetter {
    function getFee(bool x) external view returns (uint256);

    function getPairFee(address y, bool x) external view returns (uint256);

    function stableFee() external view returns (uint256);

    function volatileFee() external view returns (uint256);

    function pairFee(address x) external view returns (uint256);

    function getFee(address x) external view returns (uint256);

    function stable() external view returns (bool);
}

contract AddressesMantle {
    // users
    address internal testUser = 0xaaaa4a3F69b6DB76889bDfa4edBe1c0BB57BAA5c;

    address internal constant CLEO_WMNT_POOL = 0x762B916297235dc920a8c684419e41Ab0099A242;

    address internal constant veloFactory = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;

    address internal constant veloRouter = 0xCe30506F6c1Cea34aC704f93d51d55058791E497;

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

    address internal constant STRATUM_3POOL = 0xD6F312AA90Ad4C92224436a7A4a648d69482e47e;
    address internal constant STRATUM_3POOL_2 = 0x7d3621aCA02B711F5f738C9f21C1bFE294df094d;
    address internal constant STRATUM_ETH_POOL = 0xe8792eD86872FD6D8b74d0668E383454cbA15AFc;

    /**
     * DEX CONFIG
     */
    uint16 internal constant DEX_FEE_STABLES = 100;
    uint16 internal constant DEX_FEE_LOW_MEDIUM = 2500;
    uint16 internal constant DEX_FEE_LOW_HIGH = 3000;
    uint16 internal constant DEX_FEE_LOW = 500;
    uint16 internal constant DEX_FEE_NONE = 0;

    uint16 internal constant BIN_STEP_LOWEST = 1;
    uint16 internal constant BIN_STEP_LOW = 10;

    address internal constant FBTC_WBTC_POOL = 0xD39DFbfBA9E7eccd813918FfbDa10B783EA3b3C6;
    address internal constant FBTC = 0xC96dE26018A54D51c097160568752c4E3BD6C364;

    uint16 internal constant FUSION_X_V2_FEE_DENOM = 10000 - 20;
    uint16 internal constant MERCHANT_MOE_FEE_DENOM = 10000 - 30;
    uint16 internal constant BASE_DENOM = 10000;

    function getV2PairFeeDenom(uint8 fork, address pool) internal view returns (uint16) {
        if (fork == DexMappingsMantle.FUSION_X_V2) return FUSION_X_V2_FEE_DENOM;
        if (fork == DexMappingsMantle.MERCHANT_MOE) return MERCHANT_MOE_FEE_DENOM;
        if (fork == DexMappingsMantle.CLEO_V1_STABLE) {
            uint16 pairFee = uint16(IFactoryFeeGetter(CLEO_V1_FACOTRY).pairFee(pool));
            if (pairFee == 0) pairFee = uint16(IFactoryFeeGetter(CLEO_V1_FACOTRY).stableFee());
            return 10000 - pairFee;
        }
        if (fork == DexMappingsMantle.CLEO_V1_VOLAT) {
            uint16 pairFee = uint16(IFactoryFeeGetter(CLEO_V1_FACOTRY).pairFee(pool));
            if (pairFee == 0) pairFee = uint16(IFactoryFeeGetter(CLEO_V1_FACOTRY).volatileFee());
            return 10000 - pairFee;
        }
        if (fork == DexMappingsMantle.VELO_STABLE || fork == DexMappingsMantle.VELO_VOLAT) {
            uint16 pairFee = uint16(IFactoryFeeGetter(VELO_FACOTRY).pairFee(pool));
            return 10000 - pairFee;
        }
        return 0;
    }

    // exotic
    uint8 internal MERCHANT_MOE_LB = 151;
    uint8 internal WOO_FI = 150;
    uint8 internal KTX = 152;

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
