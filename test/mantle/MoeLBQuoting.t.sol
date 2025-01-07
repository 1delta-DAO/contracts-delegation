// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

interface ILBFactory {
    struct LBPairInformation {
        uint16 binStep;
        address LBPair;
        bool createdByOwner;
        bool ignoredForRouting;
    }

    function getLBPairInformation(address tokenX, address tokenY, uint256 binStep) external view returns (LBPairInformation memory);
}

/**
 * Tests Merchant Moe's LB Quoting for exact out to make sure that incomplete swaps
 * revert.
 */
contract MoeLBQuotingTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63129000, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        intitializeFullDelta();
    }

    function test_mantle_lb_quote_spot_exact_out_reverts() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensMantle.METH;
        address assetIn = TokensMantle.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 0.0005e18;

        bytes memory quotePath = getQuoteExactOutMultiLB(assetIn, assetOut);
        vm.expectRevert();
        testQuoter.quoteExactOutput(quotePath, amountOut);
    }

    function test_mantle_lb_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensMantle.USDe;
        address assetIn = TokensMantle.USDC;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 10.0005e18;

        bytes memory quotePath = getSpotExactOutMultiLBWorking(assetIn, assetOut);
        uint256 quote = testQuoter.quoteExactOutput(quotePath, amountOut);
        assert(quote > 0);
    }

    function test_mantle_lb_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensMantle.USDe;
        address assetIn = TokensMantle.USDT;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 10.0005e6;

        bytes memory quotePath = getSpotExactInSingle(assetIn, assetOut);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assert(quote > 0);
    }

    function test_mantle_lb_quote_spot_exact_in_reverts() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensMantle.WETH;
        address assetIn = TokensMantle.WMNT;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 900.0005e18;

        bytes memory quotePath = getSpotExactInSinglBroken(assetIn, assetOut);
        vm.expectRevert();
        testQuoter.quoteExactInput(quotePath, amountIn);
    }

    /** MOE LB PATH BUILDERS */

    function getQuoteExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOW;
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, TokensMantle.WMNT, BIN_STEP_LOWEST).LBPair;
        bytes memory firstPart = abi.encodePacked(tokenOut, poolId, pool, TokensMantle.WMNT);
        fee = DEX_FEE_LOW_MEDIUM;
        poolId = DexMappingsMantle.FUSION_X;
        pool = testQuoter._v3TypePool(TokensMantle.WMNT, tokenIn, poolId, fee);
        return abi.encodePacked(firstPart, poolId, pool, fee, tokenIn);
    }

    function getSpotExactOutMultiLBWorking(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOWEST;
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, TokensMantle.USDT, fee).LBPair;
        bytes memory firstPart = abi.encodePacked(tokenOut, poolId, pool, TokensMantle.USDT);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter._v2TypePairAddress(TokensMantle.USDT, tokenIn, poolId);
        return abi.encodePacked(firstPart, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn);
    }

    function getSpotExactInSinglBroken(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOW;
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, tokenIn, fee).LBPair;
        return abi.encodePacked(tokenIn, poolId, pool, tokenOut);
    }

    function getSpotExactInSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOWEST;
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, tokenIn, fee).LBPair;
        return abi.encodePacked(tokenIn, poolId, pool, tokenOut);
    }
}
