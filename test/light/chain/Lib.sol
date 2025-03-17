// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TokenNames {
    // Tokens
    string internal constant NATIVE = "NATIVE";
    string internal constant WRAPPED_NATIVE = "WRAPPED_NATIVE";
    string internal constant WETH = "WETH";

    string internal constant wstETH = "wstETH";
    string internal constant weETH = "weETH";
    string internal constant cbETH = "cbETH";
    string internal constant ezETH = "ezETH";
    string internal constant wrsETH = "wrsETH";

    string internal constant USDC = "USDC";
    string internal constant USDT = "USDT";
    string internal constant USDbC = "USDbC";
    string internal constant GHO = "GHO";
    string internal constant DAI = "DAI";

    string internal constant ARB = "ARB";

    string internal constant AERO = "AERO";

    string internal constant cbBTC = "cbBTC";
    /// @dev Lombard Staked BTC (LBTC)
    string internal constant LBTC = "LBTC";

    // Compound V2
    string internal constant CompV2_ETH = "CompV2_ETH";
    string internal constant CompV2_USDC = "cUSDC_V2";
    string internal constant COMPTROLLER = "COMPTROLLER";
    string internal constant VENUS_COMPTROLLER = "VENUS_COMPTROLLER";
    string internal constant VENUS_ETH_COMPTROLLER = "VENUS_ETH_COMPTROLLER";

    // Compound V3
    string internal constant COMPOUND_V3_USDC_BASE = "COMPOUND_V3_USDC_BASE";
    string internal constant COMPOUND_V3_USDC_COMET = "COMPOUND_V3_USDC_COMET";
    string internal constant COMPOUND_V3_USDBC_BASE = "COMPOUND_V3_USDBC_BASE";
    string internal constant COMPOUND_V3_USDBC_COMET = "COMPOUND_V3_USDBC_COMET";
    string internal constant COMPOUND_V3_WETH_BASE = "COMPOUND_V3_WETH_BASE";
    string internal constant COMPOUND_V3_WETH_COMET = "COMPOUND_V3_WETH_COMET";
    string internal constant COMPOUND_V3_AERO_BASE = "COMPOUND_V3_AERO_BASE";
    string internal constant COMPOUND_V3_AERO_COMET = "COMPOUND_V3_AERO_COMET";

    // Balancer V2
    string internal constant BALANCER_V2_VAULT = "BALANCER_V2_VAULT";

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

    // Granary
    string internal constant GRANARY_POOL = "GRANARY_POOL";

    // Morpho
    string internal constant META_MORPHO_USDC = "META_MORPHO_USDC";
    string internal constant MORPHO = "MORPHO";
}

library ChainIds {
    uint256 internal constant ETHEREUM = 1;
    uint256 internal constant AVALANCHE = 43114;
    uint256 internal constant BASE = 8453;
    uint256 internal constant ARBITRUM = 42161;
}
