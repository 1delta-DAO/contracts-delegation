// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests KTX / GMX style DEXs exact in swaps
 */
contract KTXTest is DeltaSetup {

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 62267594, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
    }

    function test_mantle_ktx_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WETH;
        address assetOut = WBTC;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e18;

        uint256 quoted = testQuoter._quoteKTXExactIn(assetIn, assetOut, amountIn);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleKTX(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;
        calls[1] = abi.encodeWithSelector(
            IFlashAggregator.swapExactInSpot.selector, // 3 args
            amountIn,
            minimumOut,
            user,
            swapPath
        );

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(102174291, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    // this one tests that the quoter reverts if hte output amount is higher than the vault balance
    function test_mantle_ktx_spot_exact_in_low_balance() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WETH;
        address assetOut = METH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e18;

        vm.expectRevert();
        testQuoter._quoteKTXExactIn(assetIn, assetOut, amountIn);
    }

    function test_mantle_ktx_spot_exact_in_stable_out() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WBTC;
        address assetOut = USDT;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 1.0e8;

        uint256 quoted = testQuoter._quoteKTXExactIn(assetIn, assetOut, amountIn);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleKTX(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;
        calls[1] = abi.encodeWithSelector(
            IFlashAggregator.swapExactInSpot.selector, // 3 args
            amountIn,
            minimumOut,
            user,
            swapPath
        );

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(70047916290, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_ktx_spot_exact_in_stable_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = USDT;
        address assetOut = WBTC;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 10000.0e6;

        uint256 quoted = testQuoter._quoteKTXExactIn(assetIn, assetOut, amountIn);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleKTX(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;
        calls[1] = abi.encodeWithSelector(
            IFlashAggregator.swapExactInSpot.selector, // 3 args
            amountIn,
            minimumOut,
            user,
            swapPath
        );

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(14034168, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** KTX PATH BUILDERS */

    function getSpotExactInSingleKTX(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = KTX;
        return abi.encodePacked(tokenIn, uint8(0), poolId, tokenOut);
    }
}
