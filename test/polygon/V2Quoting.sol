// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests Merchant Moe's LB Quoting for exact out to make sure that incomplete swaps
 * revert.
 */
contract PolygonQuotingTest is DeltaSetup {
    function test_polygon_V2_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDC;
        address assetIn = WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 1.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetIn, assetOut, QUICK_V2, QUICK_V2_FEE_DENOM);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(3373724906, quote, 0);
    }

    function test_polygon_V2_polycat_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = WBTC;
        address assetIn = DAI;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 100.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetIn, assetOut, POLYCAT, POLYCAT_FEE_DENOM);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(163152, quote, 0);
    }

    function test_polygon_V2_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDC;
        address assetIn = WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 3100.0005e6;

        bytes memory quotePath = getSpotQuotePathSingle(assetOut, assetIn, QUICK_V2, QUICK_V2_FEE_DENOM);
        uint256 quote = testQuoter.quoteExactOutput(quotePath, amountIn);
        assertApproxEqAbs(919125098675979978, quote, 0);
    }

    function test_izi_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDT;
        address assetIn = WMATIC;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 3.0005e6;

        bytes memory quotePath = getSpotQuotePathSingle_izi(assetOut, assetIn);
        uint256 quote = testQuoter.quoteExactOutput(quotePath, amountIn);
        assertApproxEqAbs(5406712093737610130, quote, 0);
    }

    function getSpotQuotePathSingle(address tokenIn, address tokenOut, uint8 poolId, uint16 feeDenom) internal view returns (bytes memory data) {
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, feeDenom, tokenOut);
    }

    function getSpotQuotePathSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        address pool = testQuoter._getiZiPool(tokenIn, tokenOut, 400);
        return abi.encodePacked(tokenIn, IZUMI, pool, uint16(400), tokenOut);
    }
}
