// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/modules/shared/MetaAggregator.sol";
import "../../contracts/1delta/test/MockERC20WithPermit.sol";
import "../../contracts/1delta/test/MockRouter.sol";

contract Nothing {
    function call() external {}
}

contract MetaAggregatorTest is DeltaSetup {
    uint256 constant ERC20_PERMIT_LENGTH = 224;
    uint256 constant COMPACT_ERC20_PERMIT_LENGTH = 100;

    function test_meta_aggregator() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        DeltaMetaAggregator aggr = new DeltaMetaAggregator();
        Nothing _swapTarget = new Nothing();
        address swapTarget = address(_swapTarget);
        address token = USDT;

        deal(token, user, 20e20);

        uint256 amount = 1e6;

        vm.startPrank(user);
        IERC20All(token).approve(address(aggr), amount);

        uint256 gas = gasleft();
        aggr.swapMeta(
            "",
            abi.encodeWithSelector(Nothing.call.selector), // no args
            token,
            amount,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_meta_aggregator_diff() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        DeltaMetaAggregator aggr = new DeltaMetaAggregator();
        Nothing _swapTarget = new Nothing();
        Nothing _approvalTarget = new Nothing();
        address swapTarget = address(_swapTarget);
        address approvalTarget = address(_approvalTarget);
        address token = USDT;

        deal(token, user, 20e20);

        uint256 amount = 1e6;

        vm.startPrank(user);
        IERC20All(token).approve(address(aggr), amount);

        uint256 gas = gasleft();
        aggr.swapMeta(
            "",
            abi.encodeWithSelector(Nothing.call.selector), // no args
            token,
            amount,
            approvalTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_meta_aggregator_erc20permit() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        MockERC20 tokenIn = new MockERC20("Mock", "MCK", 18);
        address assetOut = USDT;

        MockRouter router = new MockRouter(assetOut);
        DeltaMetaAggregator aggr = new DeltaMetaAggregator();

        address swapTarget = address(router);

        uint256 amountIn = 1e18;
        uint256 amountOut = 1e6;

        deal(address(tokenIn), user, amountIn);
        deal(assetOut, address(router), amountOut);
        router.setPayout(amountOut);

        bytes memory permitData = tokenIn.encodeERC20Permit(user, address(aggr), amountIn);
        bytes memory swapData = router.encodeSwap(address(tokenIn), amountIn, user);

        assertEq(permitData.length, ERC20_PERMIT_LENGTH);

        vm.startPrank(user);
        aggr.swapMeta(
            permitData,
            swapData,
            address(tokenIn),
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(user), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(user)), amountOut);

        assertEq(tokenIn.balanceOf(address(router)), amountIn);
        assertEq(IERC20All(assetOut).balanceOf(address(router)), 0);

        assertEq(tokenIn.balanceOf(address(aggr)), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(aggr)), 0);
    }

    function test_meta_aggregator_erc20permit_compact() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        MockERC20 tokenIn = new MockERC20("Mock", "MCK", 18);
        address assetOut = USDT;

        MockRouter router = new MockRouter(assetOut);
        DeltaMetaAggregator aggr = new DeltaMetaAggregator();

        address swapTarget = address(router);

        uint256 amountIn = 1e18;
        uint256 amountOut = 1e6;

        deal(address(tokenIn), user, amountIn);
        deal(assetOut, address(router), amountOut);
        router.setPayout(amountOut);

        bytes memory permitData = tokenIn.encodeCompactERC20Permit(amountIn);
        bytes memory swapData = router.encodeSwap(address(tokenIn), amountIn, user);

        assertEq(permitData.length, COMPACT_ERC20_PERMIT_LENGTH);

        vm.startPrank(user);
        aggr.swapMeta(
            permitData,
            swapData,
            address(tokenIn),
            amountIn,
            swapTarget,
            swapTarget,
            false
        );
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(user), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(user)), amountOut);

        assertEq(tokenIn.balanceOf(address(router)), amountIn);
        assertEq(IERC20All(assetOut).balanceOf(address(router)), 0);

        assertEq(tokenIn.balanceOf(address(aggr)), 0);
        assertEq(IERC20All(assetOut).balanceOf(address(aggr)), 0);
    }
}
