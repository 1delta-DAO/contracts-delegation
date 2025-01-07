// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests Uni V3 style DEX
 */
contract GeneralMoeLBTest is DeltaSetup {

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 66756564, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        intitializeFullDelta();
    }

    function test_mantle_puff_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.METH;
        address assetOut = TokensMantle.PUFF;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e18;

        uint256 quote = testQuoter.quoteExactInput(getSpotQuoteExactInSinglePuff(assetIn, assetOut), amountIn);

        bytes memory swapPath = getSpotExactInSinglePuff(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(762482577975592474750358, balanceOut, 1);
        assertApproxEqAbs(quote, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_uni_v3_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.WMNT;
        address assetOut = TokensMantle.USDT;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e18;

        uint256 quote = testQuoter.quoteExactInput(getSpotQuoteExactInSingleUniV3(assetIn, assetOut), amountIn);

        bytes memory swapPath = getSpotExactInSingleUniswap(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 20 TokensMantle.WMNT, receive approx 17, but in 6 decs
        assertApproxEqAbs(17350954, balanceOut, 1);
        assertApproxEqAbs(quote, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_crust_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.USDC;
        address assetOut = TokensMantle.USDT;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e6;

        uint256 quote = testQuoter.quoteExactInput(getSpotQuoteExactInSingleCrust(assetIn, assetOut), amountIn);

        bytes memory swapPath = getSpotExactInSingleCrust(assetIn, assetOut);
        uint256 minimumOut = 19.03e6;

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 20 TokensMantle.USDC, receive approx 20, but in 6 decs
        assertApproxEqAbs(19983297, balanceOut, 1);
        assertApproxEqAbs(quote, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** UNISWAP FORK PATH BUILDERS */

    function getSpotExactInSinglePuff(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 3000;
        uint8 poolId = DexMappingsMantle.METHLAB_POOL_ID;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactInSingleUniswap(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 500;
        uint8 poolId = DexMappingsMantle.UNISWAP_V3_POOL_ID;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactInSingleCrust(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 500;
        uint8 poolId = DexMappingsMantle.CRUST_POOL_ID;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotQuoteExactInSinglePuff(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = 3000;
        uint8 poolId = DexMappingsMantle.METHLAB_POOL_ID;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, fee, tokenOut);
    }

    function getSpotQuoteExactInSingleUniV3(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 500;
        uint8 poolId = DexMappingsMantle.UNISWAP_V3_POOL_ID;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, fee, tokenOut);
    }

    function getSpotQuoteExactInSingleCrust(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 500;
        uint8 poolId = DexMappingsMantle.CRUST_POOL_ID;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, fee, tokenOut);
    }
}
