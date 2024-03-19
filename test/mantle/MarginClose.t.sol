// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginCloseTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_close_exact_in(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactInSingle(asset, borrowAsset, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 14.0e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(14005000729747140590, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_in_multi(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactInMulti(asset, borrowAsset, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 9.0e18; // this one provides a bad swap rate
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(9189374971189364158, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_out(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactOutSingle(asset, borrowAsset, lenderId);
        uint256 amountOut = 15.0e18;
        uint256 amountInMaximum = 17.0e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, amountInMaximum, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(16067704, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_out_multi(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactOutMulti(asset, borrowAsset, lenderId);
        uint256 amountOut = 1.0e18;
        uint256 amountInMaximum = 17.0e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, amountInMaximum, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(1138292, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    function test_margin_mantle_close_all_in(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountIn = 15.0e6;
        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;
            _deposit(asset, user, amountIn, lenderId);
            openSimple(user, USDT, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactInSingle(asset, borrowAsset, lenderId);

        uint256 minimumOut = 12.0e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapAllIn.selector, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, (amountIn * 101) / 100);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        // debt as to be zero now
        uint256 finalbalance = IERC20All(collateralAsset).balanceOf(user);
        assertApproxEqAbs(finalbalance, 0, 0);

        balance = balance - finalbalance;
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(13899780205587954235, borrowBalance, 1);
    }

    function test_margin_mantle_close_all_out(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToLeverage = 30.0e18;

        {
            uint256 amountToDeposit = 10.0e6;
            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactOutSingle(asset, borrowAsset, lenderId);
        uint256 amountInMaximum = 35.0e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapAllOut.selector, amountInMaximum, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        // expect zero debt left
        uint256 borrowBalanceFinal = IERC20All(debtAsset).balanceOf(user);
        assertApproxEqAbs(0, borrowBalanceFinal, 1);

        // compute delta
        borrowBalance = borrowBalance - borrowBalanceFinal;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(32196203, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountToLeverage, borrowBalance, 1);
    }

    /** TESTS FOR THE V2 CALLBACKS */

    function test_margin_mantle_close_exact_in_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactInSingleV2(asset, borrowAsset, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 13.0e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(13927228802688539876, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_in_multi_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactInMultiV2(asset, borrowAsset, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 9.0e18; // this one provides a bad swap rate
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(13843679113549758027, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_out_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactOutSingleV2(asset, borrowAsset, lenderId);
        uint256 amountOut = 15.0e18;
        uint256 amountInMaximum = 17.0e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, amountInMaximum, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(16155425, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    function test_margin_mantle_close_all_out_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToLeverage = 30.0e18;

        {
            uint256 amountToDeposit = 10.0e6;
            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactOutSingleV2(asset, borrowAsset, lenderId);
        uint256 amountInMaximum = 35.0e6;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapAllOut.selector, amountInMaximum, swapPath);

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        // expect zero debt left
        uint256 borrowBalanceFinal = IERC20All(debtAsset).balanceOf(user);
        assertApproxEqAbs(0, borrowBalanceFinal, 1);

        // compute delta
        borrowBalance = borrowBalance - borrowBalanceFinal;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(32311441, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountToLeverage, borrowBalance, 1);
    }

    /** HELPER FOR ALL IN */

    function _deposit(address asset, address user, uint256 amount, uint8 lenderId) internal {
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amount);
        // create calls for open
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amount);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        vm.prank(user);
        brokerProxy.multicall(calls);
    }
}
