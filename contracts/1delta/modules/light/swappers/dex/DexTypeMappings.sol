// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

library DexTypeMappings {
    uint256 internal constant UNISWAP_V3_ID = 0;
    uint256 internal constant IZI_ID =  1;
    uint256 internal constant UNISWAP_V4_ID = 2;
    uint256 internal constant BALANCER_V3_ID = 4;

    uint256 internal constant BALANCER_V2_ID = 3;
    uint256 internal constant UNISWAP_V2_ID = 6;
    uint256 internal constant UNISWAP_V2_FOT_ID = 7;

    // all DEX that behave like curve
    // indexs as input
    // returns out amount
    uint256 internal constant CURVE_V1_STANDARD_ID = 60;
    // almost like curve, but slight different implementation,
    // e.g. the function returns no output
    uint256 internal constant CURVE_FORK_ID = 61;

    // pre-fundeds
    uint256 internal constant UNISWAP_V2_MAX_ID = 150;

    // exotics
    uint256 internal constant CURVE_RECEIVED_ID = 150;
    uint256 internal constant WOO_FI_ID = 155;
    uint256 internal constant LB_ID = 160;
    uint256 internal constant GMX_ID = 170;
    uint256 internal constant KTX_ID = 171;
    uint256 internal constant MAX_GMX_ID = 173;
    uint256 internal constant DODO_ID = 180;
    uint256 internal constant SYNC_SWAP_ID = 190;
    uint256 internal constant NATIVE_WRAP_ID = 254;
}
