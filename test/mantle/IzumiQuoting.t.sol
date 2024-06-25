// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests Merchant Moe's LB Quoting for exact out to make sure that incomplete swaps
 * revert.
 */
contract IzumiQuotingTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63134243, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
    }

    function test_mantle_izumi_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDC;
        address assetIn = WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 1.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetIn, assetOut);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(2209316977, quote, 1);
    }
    function test_mantle_izumi_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDC;
        address assetIn = WETH;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 3100.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetOut, assetIn);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountOut);
        assertApproxEqAbs(2485650681, quote, 1);
    }


    function getSpotQuotePathSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenIn, poolId, pool, fee, tokenOut);
    }
}
