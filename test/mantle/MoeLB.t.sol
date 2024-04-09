// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginOpenTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_mantle_lb_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = USDT;
        address assetOut = USDe;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleLB(assetIn, assetOut);
        uint256 minimumOut = 10.0e6;
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
        assertApproxEqAbs(9974008398430630650, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_lb_spot_exact_out() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDT;
        address assetIn = USDe;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 10.0e6;

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactOutSingleLB(assetIn, assetOut);
        uint256 maximumIn = 10.0e18;
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

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(9977999198990258795, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 0);
    }

    function test_margin_mantle_lb_open_exact_in_multi() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = USDT;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = USDC;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user);

        uint256 amountToLeverage = 20.0e6;
        bytes memory swapPath = getOpenExactInMultiLB(borrowAsset, asset);
        uint256 minimumOut = 20.0e6;
        calls[2] = abi.encodeWithSelector(
            IFlashAggregator.flashSwapExactIn.selector, // 3 params
            amountToLeverage,
            minimumOut,
            swapPath
        );

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amountToLeverage);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        console.log("pre multicall");
        vm.prank(user);
        brokerProxy.multicall(calls);
        console.log("ASdasd");
        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(38642840, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, amountToDeposit + amountToLeverage, 1.0e8);
    }

    function test_margin_mantle_lb_open_exact_out_multi() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = USDC;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user);

        uint256 amountToReceive = 30.0e6;
        bytes memory swapPath = getOpenExactOutMultiLB(borrowAsset, asset);
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
        assertApproxEqAbs(20980519129019992249, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, amountToDeposit + amountToReceive, 0);
    }

    function getOpenExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = CLEOPATRA_CL;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDe);
        fee = BIN_STEP_LOWEST;
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getSpotExactInSingleLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOWEST;
        uint8 poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(tokenIn, fee, poolId, uint8(0), tokenOut, uint8(99));
    }

    function getSpotExactOutSingleLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOWEST;
        uint8 poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(tokenOut, fee, poolId, uint8(1), tokenIn, uint8(99));
    }

    function getSpotExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = AGNI;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDT);
        fee = BIN_STEP_LOWEST;
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getOpenExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = CLEOPATRA_CL;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, USDe);
        fee = BIN_STEP_LOWEST;
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }
}
