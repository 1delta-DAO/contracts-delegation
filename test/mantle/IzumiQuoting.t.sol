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

        intitializeFullDelta();

    }

    function test_mantle_izumi_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensMantle.USDC;
        address assetIn = TokensMantle.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 1.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetIn, assetOut);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(2209316977, quote, 1);
    }

    function test_mantle_izumi_quote_spot_exact_in_double() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.WETH;
        address mid = TokensMantle.USDC;
        address assetOut = TokensMantle.USDT;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 1.0005e18;

        bytes memory quotePath = getSpotQuotePathDouble(assetIn, mid, assetOut);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(2197292332, quote, 1);
    }

    function test_mantle_izumi_quote_spot_exact_out_double() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.WETH;
        address mid = TokensMantle.USDC;
        address assetOut = TokensMantle.USDT;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 3000.0005e6;

        bytes memory quotePath = getSpotQuotePathDouble(assetOut, mid, assetIn);
        uint256 quote = testQuoter.quoteExactOutput(quotePath, amountOut);
        // almost 1 (e18)
        assertApproxEqAbs(967352838013573654, quote, 1);
    }

    function test_mantle_izumi_quote_spot_exact_in_double_reverse() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.USDT;
        address mid = TokensMantle.USDC;
        address assetOut = TokensMantle.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 3000.0005e6;

        bytes memory quotePath = getSpotQuotePathDouble(assetIn, mid, assetOut);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(944135636768567967, quote, 1);
    }

    function test_mantle_izumi_quote_spot_exact_out_double_reverse() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.USDT;
        address mid = TokensMantle.USDC;
        address assetOut = TokensMantle.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 1.0005e18;

        bytes memory quotePath = getSpotQuotePathDouble(assetOut, mid, assetIn);
        uint256 quote = testQuoter.quoteExactOutput(quotePath, amountOut);
        // almost 1 (e18)
        assertApproxEqAbs(4039560192, quote, 1);
    }

    function test_mantle_izumi_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensMantle.USDC;
        address assetIn = TokensMantle.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 3100.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetOut, assetIn);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountOut);
        assertApproxEqAbs(1372871259790997279, quote, 1);
    }

    function getSpotQuotePathSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsMantle.IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, tokenOut, fee);
        return abi.encodePacked(tokenIn, poolId, pool, fee, tokenOut);
    }

    function getSpotQuotePathDouble(address tokenIn, address mid, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsMantle.IZUMI;
        address pool = testQuoter._getiZiPool(tokenIn, mid, fee);
        data = abi.encodePacked(tokenIn, poolId, pool, fee, mid);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter._v2TypePairAddress(mid, tokenOut, poolId);
        data = abi.encodePacked(data, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut);
    }

    function getSpotQuotePathDoubleReverse(address tokenIn, address mid, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(mid, tokenOut, poolId);
        data = abi.encodePacked(tokenIn, poolId, pool, MERCHANT_MOE_FEE_DENOM, mid);
        poolId = DexMappingsMantle.IZUMI;
        uint16 fee = DEX_FEE_LOW;
        pool = testQuoter._getiZiPool(tokenIn, mid, fee);
        data = abi.encodePacked(data, poolId, pool, fee, tokenOut);
    }
}
