// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/modules/mantle/MetaAggregator.sol";

contract Nothing {
    function call() external {}
}

contract LendingTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_mantle_meta_aggregator() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        DeltaMetaAggregator aggr = new DeltaMetaAggregator();
        Nothing _swapTarget = new Nothing();
        address swapTarget = address(_swapTarget);
        address token = USDT;

        aggr.setValidTarget(swapTarget, swapTarget, true);

        deal(token, user, 20e20);

        uint256 amount = 1e6;
        vm.prank(user);
        IERC20All(token).approve(address(aggr), amount);

        vm.prank(user);
        uint256 gas = gasleft();
        aggr.swapMeta(
            token,
            amount,
            swapTarget,
            swapTarget,
            abi.encodeWithSelector(Nothing.call.selector) // no args
        );

        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_mantle_meta_aggregator_diff() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        DeltaMetaAggregator aggr = new DeltaMetaAggregator();
        Nothing _swapTarget = new Nothing();
        Nothing _approvalTarget = new Nothing();
        address swapTarget = address(_swapTarget);
        address approvalTarget = address(_approvalTarget);
        address token = USDT;

        aggr.setValidTarget(approvalTarget, swapTarget, true);

        deal(token, user, 20e20);

        uint256 amount = 1e6;
        vm.prank(user);
        IERC20All(token).approve(address(aggr), amount);

        vm.prank(user);
        uint256 gas = gasleft();
        aggr.swapMeta(
            token,
            amount,
            approvalTarget,
            swapTarget,
            abi.encodeWithSelector(Nothing.call.selector) // no args
        );

        gas = gas - gasleft();
        console.log("gas", gas);
    }
}
