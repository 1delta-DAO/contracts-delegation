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
        address assetOut = TokensPolygon.USDC;
        address assetIn = TokensPolygon.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 1.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetIn, assetOut, DexMappingsPolygon.QUICK_V2, QUICK_V2_FEE_DENOM);
        uint256 quote = quoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(3373724906, quote, 0);
    }

    function test_polygon_V2_polycat_quote_spot_exact_in_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensPolygon.WBTC;
        address assetIn = TokensPolygon.DAI;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 100.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetIn, assetOut, DexMappingsPolygon.POLYCAT, POLYCAT_FEE_DENOM);
        uint256 quote = quoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(163152, quote, 0);
    }

    function test_polygon_V2_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensPolygon.USDC;
        address assetIn = TokensPolygon.WETH;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 3100.0005e6;

        bytes memory quotePath = getSpotQuotePathSingle(assetOut, assetIn, DexMappingsPolygon.QUICK_V2, QUICK_V2_FEE_DENOM);
        uint256 quote = quoter.quoteExactOutput(quotePath, amountOut);
        assertApproxEqAbs(919125098675979978, quote, 0);
    }

    function test_polygon_V2_quote_spot_exact_out_cometh() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensPolygon.WMATIC;
        address assetIn = TokensPolygon.wbpg;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 1.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetOut, assetIn, DexMappingsPolygon.COMETH, COMETH_FEE_DENOM);
        uint256 quote = quoter.quoteExactOutput(quotePath, amountOut);
        assertApproxEqAbs(9345139087034618630261, quote, 0);
    }

    function test_polygon_V2_quote_spot_exact_out_ape() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensPolygon.WMATIC;
        address assetIn = TokensPolygon.WBTC;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 100.0005e18;

        bytes memory quotePath = getSpotQuotePathSingle(assetOut, assetIn, DexMappingsPolygon.APESWAP, APESWAP_FEE_DENOM);
        uint256 quote = quoter.quoteExactOutput(quotePath, amountOut);
        assertApproxEqAbs(91355, quote, 0);

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountOut, //
            1e30,
            false,
            getSpotSwapPathSingle(assetOut, assetIn, DexMappingsPolygon.APESWAP, APESWAP_FEE_DENOM)
        );
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, 1e20);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_polygon_V3_quote_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensPolygon.USDC;
        address assetIn = TokensPolygon.USDT;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 100.0005e6;

        bytes memory quotePath = getSpotQuotePathSingle_cl(assetIn, assetOut, DexMappingsPolygon.UNI_V3, DEX_FEE_STABLES);
        uint256 quote = quoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(99941589, quote, 0);

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            99.0e6,
            false,
            getSpotSwapPathSingleV3(assetIn, assetOut, DexMappingsPolygon.UNI_V3, DEX_FEE_STABLES)
        );
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, 1e20);
        uint256 bal = IERC20All(assetOut).balanceOf(user);
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        bal = IERC20All(assetOut).balanceOf(user) - bal;
        assertApproxEqAbs(bal, quote, 0);
    }

    function test_polygon_quick_V3_quote_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensPolygon.USDC;
        address assetIn = TokensPolygon.USDT;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 100.0005e6;

        bytes memory quotePath = getSpotQuotePathSingle_cl(assetIn, assetOut, DexMappingsPolygon.ALGEBRA, DEX_FEE_STABLES);
        uint256 quote = quoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(99950729, quote, 0);

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            99.0e6,
            false,
            getSpotSwapPathSingleV3(assetIn, assetOut, DexMappingsPolygon.ALGEBRA, DEX_FEE_STABLES)
        );
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, 1e20);
        uint256 bal = IERC20All(assetOut).balanceOf(user);
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        bal = IERC20All(assetOut).balanceOf(user) - bal;
        assertApproxEqAbs(bal, quote, 0);
    }

    function test_polygon_sushi_quick_V2_quote_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensPolygon.USDT;
        address mid = TokensPolygon.WETH;
        address assetIn = TokensPolygon.WMATIC;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 20.0005e18;

        bytes memory quotePath = getSpotQuotePathDual(assetIn, mid, assetOut, DexMappingsPolygon.ALGEBRA, DEX_FEE_STABLES);
        uint256 quote = quoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(11059808, quote, 0);

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            9.0e6,
            false,
            getSpotSwapPathDual(assetIn, mid, assetOut, DexMappingsPolygon.ALGEBRA, DEX_FEE_STABLES)
        );
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, 1e20);
        uint256 bal = IERC20All(assetOut).balanceOf(user);
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        bal = IERC20All(assetOut).balanceOf(user) - bal;
        assertApproxEqAbs(bal, quote, 0);
    }

    function test_polygon_quick_V3_quote_spot_exact_in_dual() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensPolygon.USDC;
        address mid = TokensPolygon.DAI;
        address assetIn = TokensPolygon.USDT;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 100.0005e6;

        bytes memory quotePath = getSpotQuotePathDual_cl(assetIn, mid, assetOut, DexMappingsPolygon.ALGEBRA, DEX_FEE_STABLES);
        uint256 quote = quoter.quoteExactInput(quotePath, amountIn);
        console.log("sad");
        assertApproxEqAbs(99888121, quote, 0);

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            99.0e6,
            false,
            getSpotSwapPathDualV3(assetIn, mid, assetOut, DexMappingsPolygon.ALGEBRA, DEX_FEE_STABLES)
        );
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, 1e20);
        uint256 bal = IERC20All(assetOut).balanceOf(user);
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        bal = IERC20All(assetOut).balanceOf(user) - bal;
        assertApproxEqAbs(bal, quote, 0);
    }

    function test_izi_quote_spot_exact_out_works() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensPolygon.USDT;
        address assetIn = TokensPolygon.WMATIC;

        deal(assetIn, user, 1e30);

        uint256 amountIn = 3.0005e6;

        bytes memory quotePath = getSpotQuotePathSingle_izi(assetOut, assetIn);
        uint256 quote = quoter.quoteExactOutput(quotePath, amountIn);
        assertApproxEqAbs(5406712093737610130, quote, 0);
    }

    function test_custom_quote_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        (bytes memory quotePath, uint256 amountIn) = getData();
        uint256 quote = quoter.quoteExactInput(quotePath, amountIn);
        assertApproxEqAbs(215136, quote, 0);
    }

    function getSpotQuotePathSingle(address tokenIn, address tokenOut, uint8 poolId, uint16 feeDenom) internal view returns (bytes memory data) {
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, feeDenom, tokenOut);
    }

    function getSpotSwapPathSingle(address tokenIn, address tokenOut, uint8 poolId, uint16 feeDenom) internal view returns (bytes memory data) {
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, feeDenom, tokenOut, uint8(0), uint8(99));
    }

    function getSpotSwapPathSingleV3(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut, uint8(0), uint8(99));
    }

    function getSpotSwapPathDualV3(
        address tokenIn,
        address mid,
        address tokenOut,
        uint8 poolId,
        uint16 fee
    )
        internal
        view
        returns (bytes memory data)
    {
        address pool = testQuoter.v3TypePool(tokenIn, mid, fee, poolId);
        address pool2 = testQuoter.v3TypePool(mid, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, mid, uint8(0), poolId, pool2, fee, tokenOut, uint8(0), uint8(99));
    }

    function getSpotQuotePathSingle_izi(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        address pool = testQuoter.getiZiPool(tokenIn, tokenOut, 400);
        return abi.encodePacked(tokenIn, DexMappingsPolygon.IZUMI, pool, uint16(400), tokenOut);
    }

    function getSpotQuotePathSingle_cl(address tokenIn, address tokenOut, uint8 id, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, id);
        return abi.encodePacked(tokenIn, id, pool, fee, tokenOut);
    }

    function getSpotQuotePathDual_cl(
        address tokenIn,
        address mid,
        address tokenOut,
        uint8 id,
        uint16 fee
    )
        internal
        view
        returns (bytes memory data)
    {
        address pool = testQuoter.v3TypePool(tokenIn, mid, fee, id);
        address pool2 = testQuoter.v3TypePool(mid, tokenOut, fee, id);
        return abi.encodePacked(tokenIn, id, pool, fee, mid, id, pool2, fee, tokenOut);
    }

    function getSpotQuotePathDual(address tokenIn, address mid, address tokenOut, uint8 id, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenIn, mid, fee, id);
        address pool2 = testQuoter.v2TypePairAddress(mid, tokenOut, DexMappingsPolygon.QUICK_V2);
        return abi.encodePacked(tokenIn, id, pool, fee, mid, DexMappingsPolygon.QUICK_V2, pool2, QUICK_V2_FEE_DENOM, tokenOut);
    }

    function getSpotSwapPathDual(address tokenIn, address mid, address tokenOut, uint8 id, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenIn, mid, fee, id);
        address pool2 = testQuoter.v2TypePairAddress(mid, tokenOut, DexMappingsPolygon.QUICK_V2);
        return abi.encodePacked(tokenIn, uint8(0), id, pool, fee, mid, uint8(0), DexMappingsPolygon.QUICK_V2, pool2, QUICK_V2_FEE_DENOM, tokenOut);
    }

    function getData() internal pure returns (bytes memory path, uint256 amount) {
        path =
            hex"0d500b1d8e8ef31e21c99d1db9a6444d3adf1270011a34eabbe928bf431b679959379b2225d60d9cda01f47ceb23fd6bc0add59e62ac25578270cff1b9f6196492a0e9a04cf2d519c7fba179da43a08f5a1aea7e26f2c2132d05d31c914a87c6611c10748aeb04b58e8f";
        amount = 0x58d15e176280000;
    }

    function getData2() internal pure returns (bytes memory data) {
        data =
            hex"cdca175300000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000b1a2bc2ec500000000000000000000000000000000000000000000000000000000000000000006a0d500b1d8e8ef31e21c99d1db9a6444d3adf1270011a34eabbe928bf431b679959379b2225d60d9cda01f47ceb23fd6bc0add59e62ac25578270cff1b9f6196492a0e9a04cf2d519c7fba179da43a08f5a1aea7e26f2c2132d05d31c914a87c6611c10748aeb04b58e8f00000000000000000000000000000000000000000000";
    }
}
