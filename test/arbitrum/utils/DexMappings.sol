// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

library DexMappingsArbitrum {
    // MAX_ID values are the maximum plus 1

    // non-pre-fundeds
    uint256 internal constant UNISWAP_V3_MAX_ID = 49;
    uint256 internal constant IZI_ID = UNISWAP_V3_MAX_ID;
    uint256 internal constant BALANCER_V2_ID = 50;
    uint256 internal constant CURVE_V1_MAX_ID = 70;
    uint256 internal constant CURVE_V1_STANDARD_ID = 60;

    // pre-fundeds
    uint256 internal constant UNISWAP_V2_MAX_ID = 150;

    // exotics
    uint256 internal constant WOO_FI_ID = 150;
    uint256 internal constant CURVE_NG_ID = 151;
    uint256 internal constant LB_ID = 160;
    uint256 internal constant GMX_ID = 170;
    uint256 internal constant KTX_ID = 171;
    uint256 internal constant DODO_ID = 180;
    uint256 internal constant SYNC_SWAP_ID = 190;

    // Arbitrum Ids
    uint8 internal constant UNI_V3 = 0;
    uint8 internal constant RAMSES = 3;
    uint8 internal constant SUSHI_V3 = 1;
    uint8 internal constant ALGEBRA = 4;
    uint8 internal constant PANCAKE = 2;
    uint8 internal constant IZUMI = 49;
    uint8 internal constant BALANCER_V2_DEXID = 50;
    uint8 internal constant CURVE = 60;
    uint8 internal constant CURVE_NG = 151;

    uint8 internal constant UNI_V2 = 100;
    uint8 internal constant SUSHI_V2 = 101;
    uint8 internal constant APESWAP = 102;

    uint8 internal constant CAMELOT_V2_VOLATILE = 121;
    uint8 internal constant CAMELOT_V2_STABLE = 136;
    uint8 internal constant RAMSES_V1_STABLE = 135;
    uint8 internal constant RAMSES_V1_VOLAT = 120;
}
