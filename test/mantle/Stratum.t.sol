// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests Curve style DEXs exact in swaps
 */
contract StratumCurveTest is DeltaSetup {

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63740637, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});
        deployDelta();
        initializeDelta();
    }

    function test_mantle_stratum_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WETH;
        address assetOut = METH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 5.0e18;

        uint256 quoted = testQuoter._quoteStratumGeneral(getTokenIdEth(assetIn), getTokenIdEth(assetOut), 0, amountIn);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleStratumEth(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;
        calls[1] = abi.encodeWithSelector(
            IFlashAggregator.swapExactInSpot.selector, // 3 args
            amountIn,
            minimumOut,
            swapPath
        );

        calls[2] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 5, receive approx 4.9, but in 18 decs
        assertApproxEqAbs(4848576987354878062, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }


    function test_mantle_stratum_spot_exact_in_usd() external pure {
        return; // the usd pol is paused
        // @solhint-ignore
        // address user = testUser;
        // vm.assume(user != address(0));
        // address assetIn = USDC;
        // address assetOut = USDY;

        // deal(assetIn, user, 1e20);

        // uint256 amountIn = 5000.0e6;

        // uint256 quoted = testQuoter._quoteStratumGeneral(getTokenIdUSD(assetIn), getTokenIdUSD(assetOut), 1, amountIn);

        // bytes[] memory calls = new bytes[](3);
        // calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        // bytes memory swapPath = getSpotExactInSingleStratumUsd(assetIn, assetOut);
        // uint256 minimumOut = 0.03e8;
        // calls[1] = abi.encodeWithSelector(
        //     IFlashAggregator.swapExactInSpot.selector, // 3 args
        //     amountIn,
        //     minimumOut,
        //     swapPath
        // );

        // calls[2] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        // vm.prank(user);
        // IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        // uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        // uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        // vm.prank(user);
        // brokerProxy.multicall(calls);

        // balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        // balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // // swap 5, receive approx 4.9, but in 18 decs
        // assertApproxEqAbs(4848576987354878062, balanceOut, 1);
        // assertApproxEqAbs(quoted, balanceOut, 0);
        // assertApproxEqAbs(balanceIn, amountIn, 0);
    }


    function test_mantle_stratum_spot_exact_in_reverse() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = METH;
        address assetOut = WETH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 5.0e18;

        uint256 quoted = testQuoter._quoteStratumGeneral(getTokenIdEth(assetIn), getTokenIdEth(assetOut), 0, amountIn);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleStratumEth(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;
        calls[1] = abi.encodeWithSelector(
            IFlashAggregator.swapExactInSpot.selector, // 3 args
            amountIn,
            minimumOut,
            swapPath
        );

        calls[2] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 5, receive approx 5.1, but in 18 decs
        assertApproxEqAbs(5145484186054830252, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** STRATUM PATH BUILDERS */

    function getSpotExactInSingleStratumEth(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = STRATUM_CURVE;
        return abi.encodePacked(tokenIn, abi.encodePacked(getTokenIdEth(tokenIn),getTokenIdEth(tokenOut), uint8(0)), poolId, uint8(0), tokenOut, uint8(99));
    }

    function getTokenIdEth(address t) internal view returns(uint8) {
        if(t == METH) return 1;
        else return 0;
    }


    function getSpotExactInSingleStratumUsd(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = STRATUM_CURVE;
        return abi.encodePacked(tokenIn, abi.encodePacked(getTokenIdUSD(tokenIn),getTokenIdUSD(tokenOut), uint8(1)), poolId, uint8(0), tokenOut, uint8(99));
    }


    function getTokenIdUSD(address t) internal view returns(uint8) {
        if(t == USDC) return 0;
        if(t == USDT) return 1;
        else return 2;
    }
}
