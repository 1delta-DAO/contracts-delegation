// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

library DexMappingsMantle {
    // MAX_ID values are the maximum plus 1

    // non-pre-fundeds
    uint256 internal constant UNISWAP_V3_MAX_ID = 49;
    uint256 internal constant IZI_ID = UNISWAP_V3_MAX_ID;
    uint256 internal constant BALANCER_V2_ID = 80;
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

    uint8 internal constant AGNI = 1;
    uint8 internal constant FUSION_X = 0;
    uint8 internal constant BUTTER = 3;
    uint8 internal constant CLEOPATRA_CL = 4;
    uint8 internal constant IZUMI = 49;
    uint8 internal constant STRATUM_CURVE = 60;
    uint8 internal constant STRATUM_USD = 60;

    uint8 internal constant METHLAB_POOL_ID = 5;
    uint8 internal constant UNISWAP_V3_POOL_ID = 6;
    uint8 internal constant CRUST_POOL_ID = 7;

    uint8 internal constant FUSION_X_V2 = 100;
    uint8 internal constant MERCHANT_MOE = 101;
    // Solidly Stable
    uint8 internal constant CLEO_V1_STABLE = 135;
    uint8 internal constant STRATUM_STABLE = 136;
    uint8 internal constant VELO_STABLE = 137;

    // Solidly Volatile
    uint8 internal constant CLEO_V1_VOLAT = 120;
    uint8 internal constant STRATUM_VOLAT = 121;
    uint8 internal constant VELO_VOLAT = 122;

    uint8 internal constant MERCHANT_MOE_LB = uint8(LB_ID);
    uint8 internal constant WOO_FI = uint8(WOO_FI_ID);
    uint8 internal constant KTX = uint8(KTX_ID);

    uint8 internal constant DODO = uint8(DODO_ID);

}
