// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/quoter/test/TestQuoterMantle.sol";

/**
 * Tests Curve style DEXs exact in swaps
 */
contract GeneralMoeLBTest is DeltaSetup {
    TestQuoterMantle testQuoter;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63740637, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
        testQuoter = new TestQuoterMantle();
    }

    function test_mantle_stratum_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WETH;
        address assetOut = METH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 5.0e18;

        uint256 quoted = testQuoter._quoteStratumEth(assetIn, assetOut, amountIn);

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

    function test_mantle_stratum_spot_exact_in_reverse() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = METH;
        address assetOut = WETH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 5.0e18;

        uint256 quoted = testQuoter._quoteStratumEth(assetIn, assetOut, amountIn);

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
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = STRATUM_ETH;
        return abi.encodePacked(tokenIn, fee, poolId, uint8(0), tokenOut, uint8(99));
    }
}
