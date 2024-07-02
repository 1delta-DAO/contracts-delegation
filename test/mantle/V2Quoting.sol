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

    function test_mantle_V2_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDC;
        address assetIn = WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 1.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetIn, assetOut, MERCHANT_MOE);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(3102411711, quote, 0);
    }

    function test_mantle_V2_solidly_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = aUSD;
        address assetIn = USDC;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 1.0005e6;

        bytes memory quotePath = getSpotQuotePathSingle(assetIn, assetOut, CLEO_V1_STABLE);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(999910427647198616, quote, 0);
    }

    function test_mantle_V2_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDC;
        address assetIn = WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 3100.0005e6;

        bytes memory quotePath = getSpotQuotePathSingle(assetOut, assetIn, MERCHANT_MOE);
        uint256 quote = testQuoter.quoteExactOutput(quotePath, amountIn);
        assertApproxEqAbs(999715467997505211, quote, 0);
    }

    function test_mantle_V2_solidly_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = aUSD;
        address assetIn = USDC;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 1.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetOut, assetIn, CLEO_V1_STABLE);
        uint256 quote = testQuoter.quoteExactOutput(quotePath, amountOut);
        assertApproxEqAbs(1001091, quote, 0);
    }

    function getSpotQuotePathSingle(address tokenIn, address tokenOut, uint8 poolId) internal view returns (bytes memory data) {
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        return
            abi.encodePacked(
                tokenIn,
                poolId,
                pool,
                getV2PairFeeDenom(poolId, pool), //
                tokenOut
            );
    }
}
