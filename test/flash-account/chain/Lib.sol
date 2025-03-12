// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TokenNames {
    // Not available
    string internal constant NATIVE = "NATIVE";
    string internal constant WRAPPED_NATIVE = "WRAPPED_NATIVE";
    string internal constant USDC = "USDC";
    // Collaterals

    string internal constant CompV2_USDC = "cUSDC_V2";

    string internal constant AaveV2_USDC = "aUSDC_V2";
    string internal constant AaveV3_USDC = "aUSDC_V3";

    string internal constant AaveV2_ETH = "aWETH_V2";
    string internal constant AaveV3_ETH = "aWETH_V3";

    string internal constant AaveV2_Pool = "AAVE_V2_POOL";
    string internal constant AaveV3_Pool = "AAVE_V3_POOL";

    string internal constant COMPTROLLER = "COMPTROLLER";
}

library ChainIds {
    uint256 internal constant ETHEREUM = 1;
    uint256 internal constant AVALANCHE = 43114;
}
