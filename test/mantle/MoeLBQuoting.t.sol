// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/quoter/test/TestQuoterMantle.sol";

/**
 * Tests Merchant Moe's LB Quoting for exact out to make sure that incomplete swaps
 * revert.
 */
contract MoeLBQuotingTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable
    TestQuoterMantle testQuoter;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63129000, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
        testQuoter = new TestQuoterMantle();
    }

    function test_mantle_lb_quote_spot_exact_out_reverts() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = METH;
        address assetIn = WETH;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 0.0005e18;

        bytes memory quotePath = getQuoteExactOutMultiLB(assetIn, assetOut);
        vm.expectRevert();
        testQuoter.quoteExactOutput(quotePath, amountOut);
    }

    function test_mantle_lb_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDe;
        address assetIn = USDC;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 10.0005e18;

        bytes memory quotePath = getSpotExactOutMultiLBWorking(assetIn, assetOut);
        uint256 quote = testQuoter.quoteExactOutput(quotePath, amountOut);
        assert(quote > 0);
    }

    function test_mantle_lb_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDe;
        address assetIn = USDT;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 10.0005e6;

        bytes memory quotePath = getSpotExactInSingle(assetIn, assetOut);
        uint256 quote = testQuoter.quoteExactInput(quotePath, amountIn);
        assert(quote > 0);
    }

    function test_mantle_lb_quote_spot_exact_in_reverts() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = WETH;
        address assetIn = WMNT;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 900.0005e18;

        bytes memory quotePath = getSpotExactInSinglBroken(assetIn, assetOut);
        vm.expectRevert();
        testQuoter.quoteExactInput(quotePath, amountIn);
    }



    /** MOE LB PATH BUILDERS */

    function getQuoteExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOW;
        uint8 poolId = MERCHANT_MOE_LB;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, WMNT);
        fee = DEX_FEE_LOW_MEDIUM;
        poolId = FUSION_X;
        return abi.encodePacked(firstPart, fee, poolId, tokenIn);
    }

    function getSpotExactOutMultiLBWorking(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOWEST;
        uint8 poolId = MERCHANT_MOE_LB;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, USDT);
        fee = DEX_FEE_NONE;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, tokenIn);
    }

    function getSpotExactInSinglBroken(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOW;
        uint8 poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(tokenIn, fee, poolId, tokenOut);
    }

    function getSpotExactInSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOWEST;
        uint8 poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(tokenIn, fee, poolId, tokenOut);
    }
}
