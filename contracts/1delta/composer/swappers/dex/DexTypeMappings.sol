// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

library DexTypeMappings {
    // Blue Chip DEXs (1)
    uint256 internal constant UNISWAP_V3_ID = 0;
    uint256 internal constant IZI_ID = 1;
    uint256 internal constant UNISWAP_V4_ID = 2;
    uint256 internal constant BALANCER_V3_ID = 4;

    uint256 internal constant BALANCER_V2_ID = 3;
    uint256 internal constant UNISWAP_V2_ID = 6;
    uint256 internal constant UNISWAP_V2_FOT_ID = 7;

    // Blue Chip DEXs (2): all DEX that behave like curve
    // indexs as input
    // returns out amount
    uint256 internal constant CURVE_V1_STANDARD_ID = 60;
    // curve NG
    uint256 internal constant CURVE_RECEIVED_ID = 62;
    // almost like curve, but slight different implementation,
    // e.g. the function returns no output
    uint256 internal constant CURVE_FORK_ID = 65;

    // exotics
    uint256 internal constant WOO_FI_ID = 100;
    // LFM/LFJ LB
    uint256 internal constant LB_ID = 110;

    // GMXs
    uint256 internal constant GMX_ID = 120;
    uint256 internal constant KTX_ID = 121;

    // more exotics
    uint256 internal constant DODO_ID = 180;
    uint256 internal constant SYNC_SWAP_ID = 190;

    // wrappers
    uint256 internal constant ERC4646_ID = 253;
    uint256 internal constant NATIVE_WRAP_ID = 254;
}
