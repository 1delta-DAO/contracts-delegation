// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginOpenTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_open_exact_in(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToLeverage = 20.0e18;
        bytes memory swapPath = getOpenExactInSingle(borrowAsset, asset, lenderId);
        uint256 minimumOut = 10.0e6;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountToLeverage, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amountToLeverage);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39122533, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, amountToDeposit + amountToLeverage, 1.0e8);
    }

    function test_margin_mantle_open_exact_in_multi(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToLeverage = 20.0e18;
        bytes memory swapPath = getOpenExactInMulti(borrowAsset, asset, lenderId);
        uint256 minimumOut = 20.0e6;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountToLeverage, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amountToLeverage);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(38642840, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, amountToDeposit + amountToLeverage, 1.0e8);
    }

    function test_margin_mantle_open_exact_out(uint8 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToReceive = 30.0e6;
        bytes memory swapPath = getOpenExactOutSingle(borrowAsset, asset, lenderId);
        uint256 maximumIn = 29.0e18;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountToReceive, maximumIn, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, maximumIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(20621357675549497673, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, amountToDeposit + amountToReceive, 0);
    }

    function test_margin_mantle_open_exact_out_multi(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        console.log("TEST THE TEST");
        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit, lenderId);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToReceive = 30.0e6;
        bytes memory swapPath = getOpenExactOutMulti(borrowAsset, asset, lenderId);
        uint256 maximumIn = 29.0e18;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountToReceive, maximumIn, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, maximumIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);
        console.log("TEST THE TEST");
        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(20980519129019992249, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, amountToDeposit + amountToReceive, 0);
    }

    /** THE FOLLOWING TESTS CHECK THE CALLBACK FOR V2 */

    function test_margin_mantle_open_exact_in_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToLeverage = 20.0e18;
        bytes memory swapPath = getOpenExactInSingleV2(borrowAsset, asset, lenderId);
        uint256 minimumOut = 20.0e6;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountToLeverage, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amountToLeverage);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39923752, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, amountToDeposit + amountToLeverage, 1.0e13);
    }

    function test_margin_mantle_open_exact_in_multi_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToLeverage = 20.0e18;
        bytes memory swapPath = getOpenExactInMultiV2(borrowAsset, asset, lenderId);
        uint256 minimumOut = 20.0e6;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountToLeverage, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amountToLeverage);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39897880, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, amountToDeposit + amountToLeverage, 1.0e13);
    }

    function test_margin_mantle_open_exact_out_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToReceive = 30.0e6;
        bytes memory swapPath = getOpenExactOutSingleV2(borrowAsset, asset, lenderId);
        uint256 maximumIn = 29.0e18;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountToReceive, maximumIn, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, maximumIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(20050966249736894241, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, amountToDeposit + amountToReceive, 0);
    }


    function test_margin_mantle_open_exact_out_multi_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToReceive = 30.0e6;
        bytes memory swapPath = getOpenExactOutMultiV2(borrowAsset, asset, lenderId);
        uint256 maximumIn = 29.0e18;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountToReceive, maximumIn, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, maximumIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(20068321880954662893, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, amountToDeposit + amountToReceive, 0);
    }
}
