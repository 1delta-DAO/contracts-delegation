// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/quoter/test/TestQuoterMantle.sol";

/**
 * Tests Merchant Moe's LB in all configs
 * Exact out ath the beginning, end
 * Exact in at the begginging, end
 * Payment variations
 *  - continue swap
 *  - pay from user balance
 *  - pay with credit line
 *  - pay through withdrawal
 */
contract GeneralMoeLBTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    TestQuoterMantle testQuoter;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 62267594, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
        testQuoter = new TestQuoterMantle();
    }

    function test_mantle_ktx_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WETH;
        address assetOut = WBTC;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e18;

        uint256 quoted = testQuoter._quoteKTXExactIn(assetIn, assetOut, amountIn);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleKTX(assetIn, assetOut);
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

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(102174291, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    
    function test_mantle_ktx_spot_exact_in_stable_out() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WBTC;
        address assetOut = USDT;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 1.0e8;

        uint256 quoted = testQuoter._quoteKTXExactIn(assetIn, assetOut, amountIn);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleKTX(assetIn, assetOut);
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

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleKTX(assetIn, assetOut);
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

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(14034168, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_ktx_spot_exact_out() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = WBTC;
        address assetIn = WETH;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 102174291;

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactOutSingleKTX(assetIn, assetOut);
        uint256 maximumIn = 22.0e18;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.swapExactOutSpot.selector, // 3 args
            amountOut,
            maximumIn,
            swapPath
        );

        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // note that there is some lack of precision
        assertApproxEqAbs(20001603880000000000, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 10000);
        // we expect to receive slightly more
        assert(balanceOut >= amountOut);
    }


    function test_mantle_ktx_spot_exact_out_stable_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = WBTC;
        address assetIn = USDT;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 1.0e8;

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactOutSingleKTX(assetIn, assetOut);
        uint256 maximumIn = 79000.0e6;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.swapExactOutSpot.selector, // 3 args
            amountOut,
            maximumIn,
            swapPath
        );

        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // note that there is some lack of precision
        assertApproxEqAbs(71264910391, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 0.05e6);
        // we expect to receive slightly more
        assert(balanceOut >= amountOut);
    }


    function test_mantle_ktx_spot_exact_out_stable_out() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDT;
        address assetIn = WBTC;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 78000.0e6;

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactOutSingleKTX(assetIn, assetOut);
        uint256 maximumIn = 1.15e8;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.swapExactOutSpot.selector, // 3 args
            amountOut,
            maximumIn,
            swapPath
        );

        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // note that there is some lack of precision
        assertApproxEqAbs(111363200, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 10.0e6);
        // we expect to receive slightly more
        assert(balanceOut >= amountOut);
    }


    function test_mantle_ktx_spot_exact_out_stable_out_2() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDT;
        address assetIn = WETH;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 78000.0e6;

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactOutSingleKTX(assetIn, assetOut);
        uint256 maximumIn = 25.15e18;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.swapExactOutSpot.selector, // 3 args
            amountOut,
            maximumIn,
            swapPath
        );

        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // note that there is some lack of precision
        assertApproxEqAbs(21580314000000000000, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 10.0e6);
        // we expect to receive slightly more
        assert(balanceOut >= amountOut);
    }


    /** KTX PATH BUILDERS */

    function getSpotExactInSingleKTX(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = KTX;
        return abi.encodePacked(tokenIn, fee, poolId, uint8(0), tokenOut, uint8(99));
    }

    function getSpotExactOutSingleKTX(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOWEST;
        uint8 poolId = KTX;
        return abi.encodePacked(tokenOut, fee, poolId, uint8(1), tokenIn, uint8(99));
    }
}
