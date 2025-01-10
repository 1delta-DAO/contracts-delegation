// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

library DexMappingsPolygon {
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
    uint256 internal constant CURVE_RECEIVED_ID = 151;
    uint256 internal constant LB_ID = 160;
    uint256 internal constant GMX_ID = 170;
    uint256 internal constant KTX_ID = 171;
    uint256 internal constant DODO_ID = 180;
    uint256 internal constant SYNC_SWAP_ID = 190;

    // Polygon Ids
    uint8 internal constant UNI_V3 = 0;
    uint8 internal constant RETRO = 1;
    uint8 internal constant SUSHI_V3 = 2;
    uint8 internal constant ALGEBRA = 3;
    uint8 internal constant IZUMI = 49;
    uint8 internal constant BALANCER = uint8(BALANCER_V2_ID);
    uint8 internal constant CURVE = 60;
    uint8 internal constant CURVE_NG = 151;
    uint8 internal constant CURVE_META = 65;

    uint8 internal constant UNI_V2 = 100;
    uint8 internal constant QUICK_V2 = 101;
    uint8 internal constant SUSHI_V2 = 102;
    uint8 internal constant DFYN = 103;
    uint8 internal constant POLYCAT = 104;
    uint8 internal constant APESWAP = 105;
    uint8 internal constant COMETH = 106;

}
