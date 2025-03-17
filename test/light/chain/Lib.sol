// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TokenNames {
    // Tokens
    string internal constant NATIVE = "NATIVE";
    string internal constant WRAPPED_NATIVE = "WRAPPED_NATIVE";
    string internal constant WETH = "WETH";
    string internal constant USDC = "USDC";
    string internal constant cbETH = "cbETH";
    string internal constant USDbC = "USDbC";
    string internal constant wstETH = "wstETH";
    string internal constant weETH = "weETH";
    string internal constant cbBTC = "cbBTC";
    string internal constant ezETH = "ezETH";
    string internal constant GHO = "GHO";
    /// @dev Lombard Staked BTC (LBTC)
    string internal constant LBTC = "LBTC";


    // Compound V2
    string internal constant CompV2_ETH = "CompV2_ETH";
    string internal constant CompV2_USDC = "cUSDC_V2";
    string internal constant COMPTROLLER = "COMPTROLLER";

    // Balancer V3
    string internal constant BALANCER_V3_VAULT = "BALANCER_V3_VAULT";

    // Aave V2
    string internal constant AaveV2_Pool = "AAVE_V2_POOL";
    string internal constant AaveV2_USDC = "aUSDC_V2";
    string internal constant AaveV2_ETH = "aWETH_V2";

    // Aave V3
    string internal constant AaveV3_Pool = "AAVE_V3_POOL";
    string internal constant AaveV3_USDC = "aUSDC_V3";
    string internal constant AaveV3_ETH = "aWETH_V3";
}

library ChainIds {
    uint256 internal constant ETHEREUM = 1;
    uint256 internal constant AVALANCHE = 43114;
    uint256 internal constant BASE = 8453;
}
