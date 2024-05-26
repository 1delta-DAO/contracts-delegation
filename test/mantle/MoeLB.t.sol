// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

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

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 62267594, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
    }

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
            user,
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
        assertApproxEqAbs(9973011097320898560, balanceOut, 1);
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
            user,
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
        assertApproxEqAbs(9977001498840374757, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 0);
    }

    function test_mantle_lb_spot_exact_out_multi() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDe;
        address assetIn = USDC;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 10.0e18;

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactOutMultiLB(assetIn, assetOut);
        uint256 maximumIn = 10.5e6;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.swapExactOutSpot.selector, // 3 args
            amountOut,
            maximumIn,
            user,
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
        assertApproxEqAbs(10091372, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 1e12);
    }

    function test_mantle_lb_spot_exact_out_multi_end() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = USDC;
        address assetIn = USDe;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 10.0e6;

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactOutMultiLBEnd(assetIn, assetOut);
        uint256 maximumIn = 10.5e18;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.swapExactOutSpot.selector, // 3 args
            amountOut,
            maximumIn,
            user,
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
        assertApproxEqAbs(9973416762201841411, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 1e12);
    }

    function test_margin_mantle_lb_open_exact_in_multi() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = USDT;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = USDC;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        uint256 amountToDeposit = 10.0e6;

        _deposit(user, asset, amountToDeposit);

        bytes[] memory calls = new bytes[](1);
        uint256 amountToLeverage = 2.0e6;
        bytes memory swapPath = getOpenExactInMultiLB(borrowAsset, asset);
        uint256 minimumOut = 1.95e6;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.flashSwapExactIn.selector, // 3 params
            amountToLeverage,
            minimumOut, //
            swapPath
        );

        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amountToLeverage);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // swap 2.0 for approx 1.98
        assertApproxEqAbs(1983226, balance, 1);
        assertApproxEqAbs(borrowBalance, amountToLeverage, 0);
    }

    function test_margin_mantle_lb_open_exact_out_multi() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = USDT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToDeposit = 10.0e6;

        _deposit(user, asset, amountToDeposit);

        bytes[] memory calls = new bytes[](1);
        uint256 amountToReceive = 2.0e6;
        bytes memory swapPath = getOpenExactOutMultiLB(borrowAsset, asset);
        uint256 maximumIn = 2.05e6;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.flashSwapExactOut.selector, //
            amountToReceive,
            maximumIn, //
            swapPath
        );

        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, maximumIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(2022639, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, amountToReceive, 0);
    }

    function test_margin_mantle_lb_close_exact_in_multi() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = USDT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 30.0e6;
            uint256 amountToLeverage = 10.0e6;
            _deposit(user, asset, amountToDeposit);
            _borrow(user, borrowAsset, amountToLeverage);
        }

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactInMultiLB(asset, borrowAsset);
        uint256 amountIn = 1.5e6;
        uint256 minimumOut = 1.48e6; // this one provides a bad swap rate
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.flashSwapExactIn.selector, //
            amountIn,
            minimumOut,
            swapPath
        );

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        assertApproxEqAbs(amountIn, balance, 1);
        // receive approx. 1.5 from 1.5 stable swap
        assertApproxEqAbs(1489871, borrowBalance, 1);
    }

    function test_margin_mantle_lb_close_exact_out_multi() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDT;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = USDC;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 30.0e6;
            uint256 amountToLeverage = 10.0e6;
            _deposit(user, asset, amountToDeposit);
            _borrow(user, borrowAsset, amountToLeverage);
        }
        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getCloseExactOutMultiLB(asset, borrowAsset);
        uint256 amountOut = 1.0e6;
        uint256 amountInMaximum = 1.20e6;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.flashSwapExactOut.selector,
            amountOut, //
            amountInMaximum,
            swapPath
        );

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(1007949, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    /** MOE LB PATH BUILDERS */

    function getOpenExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, USDe);
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, midId, poolId, BIN_STEP_LOWEST, tokenOut, DEFAULT_LENDER, endId);
    }

    function getSpotExactInSingleLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = BIN_STEP_LOWEST;
        uint8 poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(tokenIn, uint8(0), poolId, fee, tokenOut, uint8(99));
    }

    function getSpotExactOutSingleLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(tokenOut, uint8(1), poolId, BIN_STEP_LOWEST, tokenIn);
    }

    function getSpotExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE_LB;
        bytes memory firstPart = abi.encodePacked(tokenOut, uint8(1), poolId, BIN_STEP_LOWEST, USDT);
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, uint8(1), poolId, tokenIn);
    }

    function getSpotExactOutMultiLBEnd(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenOut, uint8(1), poolId, USDT);
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, uint8(1), poolId, BIN_STEP_LOWEST, tokenIn);
    }

    function getSpotExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = AGNI;
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, DEX_FEE_LOW, USDT);
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, midId, poolId, BIN_STEP_LOWEST, tokenOut, endId);
    }

    function getOpenExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, MERCHANT_MOE, USDe);
        return abi.encodePacked(firstPart, midId, MERCHANT_MOE_LB, BIN_STEP_LOWEST, tokenIn, DEFAULT_LENDER, endId);
    }

    function getCloseExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, MERCHANT_MOE, USDe);
        return abi.encodePacked(firstPart, midId, MERCHANT_MOE_LB, BIN_STEP_LOWEST, tokenIn, DEFAULT_LENDER, endId);
    }

    function getCloseExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, MERCHANT_MOE, USDe);
        return abi.encodePacked(firstPart, midId, MERCHANT_MOE_LB, BIN_STEP_LOWEST, tokenOut, DEFAULT_LENDER, endId);
    }

    /** DEPO AND BORROW HELPER */

    function _deposit(address user, address asset, uint256 amount) internal {
        deal(asset, user, amount);
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amount);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amount);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, DEFAULT_LENDER);
        vm.prank(user);
        brokerProxy.multicall(calls);
    }

    function _borrow(address user, address asset, uint256 amount) internal {
        address debtAsset = debtTokens[asset][DEFAULT_LENDER];
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amount);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.borrow.selector, asset, amount, DEFAULT_IR_MODE, DEFAULT_LENDER);
        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, asset, user);
        vm.prank(user);
        brokerProxy.multicall(calls);
    }
}
