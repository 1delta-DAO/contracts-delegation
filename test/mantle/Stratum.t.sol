// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests Curve style DEXs exact in swaps
 */
contract StratumCurveTest is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63740637, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});
        intitializeFullDelta();
    }

    function test_mantle_stratum_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WETH;
        address assetOut = METH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 5.0e18;

        uint256 quoted = testQuoter._quoteStratumGeneral(getTokenIdEth(assetIn), getTokenIdEth(assetOut), STRATUM_ETH_POOL, amountIn);

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

    function test_mantle_stratum_spot_exact_in_usd() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = USDC;
        address assetOut = USDY;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 2000.0e6;

        uint256 quoted = testQuoter.quoteExactInput(
            getSpotExactInSingleStratumUsdQuter(assetIn, assetOut),
            amountIn //
        );

        bytes memory swapPath = getSpotExactInSingleStratumUsdTrade(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn,
            minimumOut,
            false, // not self
            swapPath
        );

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 5, receive approx 4.9, but in 18 decs
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(quoted, 1934254534138061721830, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_stratum_spot_exact_in_reverse() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = METH;
        address assetOut = WETH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 5.0e18;

        uint256 quoted = testQuoter._quoteStratumGeneral(getTokenIdEth(assetIn), getTokenIdEth(assetOut), STRATUM_ETH_POOL, amountIn);

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

    function getSpotExactInSingleStratumEth(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                tokenIn,
                uint8(0),
                STRATUM_CURVE,
                STRATUM_ETH_POOL,
                abi.encodePacked(getTokenIdEth(tokenIn), getTokenIdEth(tokenOut)),
                tokenOut
            );
    }

    function getTokenIdEth(address t) internal view returns (uint8) {
        if (t == METH) return 1;
        else return 0;
    }

    function getSpotExactInSingleStratumUsd(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = STRATUM_CURVE;
        return
            abi.encodePacked(
                tokenIn,
                uint8(0),
                poolId,
                STRATUM_3POOL_2,
                abi.encodePacked(getTokenIdUSD(tokenIn), getTokenIdUSD(tokenOut)),
                tokenOut,
                uint8(99),
                uint8(0)
            );
    }

    function getSpotExactInSingleStratumUsdQuter(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                tokenIn,
                STRATUM_USD, // pid
                tokenOut
            );
    }

    function getSpotExactInSingleStratumUsdTrade(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                tokenIn,
                uint8(0), //action
                STRATUM_USD, // only Id
                tokenOut,
                uint8(0),
                uint8(0)
            );
    }

    function getTokenIdUSD(address t) internal view returns (uint8) {
        if (t == USDC) return 0;
        if (t == USDT) return 1;
        else return 2;
    }

    function getTokenIdUSDY(address t) internal view returns (uint8) {
        if (t == USDC) return 1;
        if (t == USDT) return 2;
        else return 0;
    }
}
