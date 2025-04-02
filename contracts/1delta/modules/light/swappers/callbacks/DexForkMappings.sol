// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

library DexForkMappings {
    uint256 internal constant UNISWAP_V3 = 0;

    // classifier for skipping validation and paying the pool from the contract
    uint256 internal constant ANY_V3 = 0xff;

    uint256 internal constant IZI = 0;
    uint256 internal constant ANY_IZI = 0xff;

    // explicits
    uint256 internal constant UNISWAP_V4 = 0;
    uint256 internal constant BALANCER_V3 = 0;
    uint256 internal constant UNISWAP_V2 = 0;
}
