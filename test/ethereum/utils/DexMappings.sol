// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

library DexMappingsEthereum {
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
    uint256 internal constant WOO_FI_ID = 155;
    uint256 internal constant CURVE_RECEIVED_ID = 150;
    uint256 internal constant LB_ID = 160;
    uint256 internal constant GMX_ID = 170;
    uint256 internal constant KTX_ID = 171;
    uint256 internal constant DODO_ID = 180;
    uint256 internal constant SYNC_SWAP_ID = 190;

    // Taiko Ids

    uint8 internal constant PANCAKE_V3 = 2;
    uint8 internal constant SOLIDLY_V3 = 2;
    uint8 internal constant HENJIN = 2;
    uint8 internal constant SUSHI_V3 = 3;
    uint8 internal constant SWAPSICLE = 5;
    uint8 internal constant DTX = 1;
    uint8 internal constant UNI_V3 = 0;
    uint8 internal constant UNI_V2 = 100;
    uint8 internal constant IZUMI = 49;
    uint8 internal constant PANKO_DEX_ID = 3;
    uint8 internal constant PANKO_STABLE_DEX_ID = 61;

    uint8 internal constant KODO_STABLE = 135;
    uint8 internal constant KODO_VOLAT = 120;
    uint8 internal constant DTXV1 = 100;
    uint8 internal constant RITSU = uint8(SYNC_SWAP_ID);

    uint8 internal constant DODO = uint8(DODO_ID);
}
