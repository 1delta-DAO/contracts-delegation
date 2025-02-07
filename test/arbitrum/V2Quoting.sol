// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests Merchant Moe's LB Quoting for exact out to make sure that incomplete swaps
 * revert.
 */
contract ArbitrumQuotingTest is DeltaSetup {
    address wbpg = 0xc0f14C88250E680eCd70224B7fBa82b7C6560d12;

    function test_arbitrum_V2_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensArbitrum.OHM;
        address assetIn = TokensArbitrum.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 0.1e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetIn, assetOut, DexMappingsArbitrum.CAMELOT_V2_VOLATILE, CAMELOT_V2_FEE_DENOM);
        uint256 quote = quoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(15672039507, quote, 0);
    }

    function test_arbitrum_V2_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensArbitrum.OHM;
        address assetIn = TokensArbitrum.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 1.0e9;

        bytes memory quotePath = getSpotQuotePathSingle(assetOut, assetIn, DexMappingsArbitrum.CAMELOT_V2_VOLATILE, CAMELOT_V2_FEE_DENOM);
        uint256 quote = quoter.quoteExactOutput(quotePath, amountOut);
        assertApproxEqAbs(6368403383400929, quote, 0);
    }

    function test_arbitrum_V3_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensArbitrum.ARB;
        address assetIn = TokensArbitrum.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 0.1e18;

        bytes memory quotePath = getQuoteSwapPathSingleV3(assetIn, assetOut, DexMappingsArbitrum.RAMSES, 500);
        uint256 quote = quoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(460939078352216629914, quote, 0);
    }

    function getSpotQuotePathSingle(address tokenIn, address tokenOut, uint8 poolId, uint16 feeDenom) internal view returns (bytes memory data) {
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, feeDenom, tokenOut);
    }

    function getSpotSwapPathSingle(address tokenIn, address tokenOut, uint8 poolId, uint16 feeDenom) internal view returns (bytes memory data) {
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, feeDenom, tokenOut, uint8(0), uint8(99));
    }

    function getQuoteSwapPathSingleV3(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, fee, tokenOut, uint8(0), uint8(99));
    }

    function getSpotSwapPathDualV3(
        address tokenIn,
        address mid,
        address tokenOut,
        uint8 poolId,
        uint16 fee
    ) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenIn, mid, fee, poolId);
        address pool2 = testQuoter.v3TypePool(mid, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, mid, uint8(0), poolId, pool2, fee, tokenOut, uint8(0), uint8(99));
    }
}
