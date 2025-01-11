// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests Curve style DEXs exact in swaps
 */
contract StratumCurveTest is DeltaSetup {
    uint8 internal constant SWAP_ID = 200;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63740637, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});
        intitializeFullDelta();
    }

    function test_mantle_stratum_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.WETH;
        address assetOut = TokensMantle.METH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 5.0e18;

        // uint256 quoted = testQuoter._quoteStratumGeneral(getTokenIdEth(assetIn), getTokenIdEth(assetOut), STRATUM_ETH_POOL, amountIn);
        uint256 quoted = quoter.quoteExactInput(getQuoteExactInSingleStratumEth(assetIn, assetOut), amountIn);

        bytes memory swapPath = getSpotExactInSingleStratumEth(assetIn, assetOut);
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

        // swap 5, receive approx 4.9, but in 18 decs
        assertApproxEqAbs(4848576987354878062, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_stratum_spot_exact_in_reverse() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.METH;
        address assetOut = TokensMantle.WETH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 5.0e18;

        // uint256 quoted = testQuoter._quoteStratumGeneral(getTokenIdEth(assetIn), getTokenIdEth(assetOut), STRATUM_ETH_POOL, amountIn);
        uint256 quoted = quoter.quoteExactInput(getQuoteExactInSingleStratumEth(assetIn, assetOut), amountIn);
        bytes memory swapPath = getSpotExactInSingleStratumEth(assetIn, assetOut);
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

        // swap 5, receive approx 5.1, but in 18 decs
        assertApproxEqAbs(5145484186054830252, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** STRATUM PATH BUILDERS */

    function getSpotExactInSingleStratumEth(address tokenIn, address tokenOut) internal pure returns (bytes memory data) {
        return
            abi.encodePacked(
                tokenIn,
                uint8(0),
                DexMappingsMantle.STRATUM_CURVE,
                STRATUM_ETH_POOL,
                abi.encodePacked(getTokenIdEth(tokenIn), getTokenIdEth(tokenOut)),
                SWAP_ID,
                tokenOut
            );
    }

    function getTokenIdEth(address t) internal pure returns (uint8) {
        if (t == TokensMantle.METH) return 1;
        else return 0;
    }

    function getSpotExactInSingleStratumUsd(address tokenIn, address tokenOut) internal pure returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.STRATUM_CURVE;
        return
            abi.encodePacked(
                tokenIn,
                uint8(0),
                poolId,
                STRATUM_3POOL_2,
                abi.encodePacked(getTokenIdUSD(tokenIn), getTokenIdUSD(tokenOut)),
                SWAP_ID,
                tokenOut,
                uint8(99),
                uint8(0)
            );
    }

    function getQuoteExactInSingleStratumEth(address tokenIn, address tokenOut) internal pure returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.STRATUM_CURVE;
        return
            abi.encodePacked(
                tokenIn,
                poolId,
                STRATUM_ETH_POOL,
                abi.encodePacked(getTokenIdEth(tokenIn), getTokenIdEth(tokenOut)),
                SWAP_ID,
                tokenOut
            );
    }

    function getTokenIdUSD(address t) internal pure returns (uint8) {
        if (t == TokensMantle.USDC) return 0;
        if (t == TokensMantle.USDT) return 1;
        else return 2;
    }

    function getTokenIdUSDY(address t) internal pure returns (uint8) {
        if (t == TokensMantle.USDC) return 1;
        if (t == TokensMantle.USDT) return 2;
        else return 0;
    }
}
