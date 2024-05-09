// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginDebtSwapTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable


    function test_margin_mantle_debt_exact_in() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactInSingle(assetFrom, borrowAsset);
        uint256 amountIn = 0.001e18;
        uint256 minimumOut = 1.7e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(debtAsset).balanceOf(user);
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(2398640388832552493, balance, 1);
    }

    function test_margin_mantle_debt_exact_in_multi() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactInMulti(assetFrom, borrowAsset);
        uint256 amountIn = 0.001e18;
        uint256 minimumOut = 1.7e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(debtAsset).balanceOf(user);
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(2399864542910992641, balance, 1);
    }

    function test_margin_mantle_debt_exact_out() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutSingle(assetFrom, borrowAsset);
        uint256 amountOut = 3.7e18;
        uint256 maxIn = 0.002e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, maxIn, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, maxIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(debtAsset).balanceOf(user);
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        //  swap 15 for approx 15
        assertApproxEqAbs(1542667073284527, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_debt_exact_out_multi() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutMulti(assetFrom, borrowAsset);
        uint256 amountOut = 3.7e18;
        uint256 maxIn = 0.004e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, maxIn, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, maxIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(debtAsset).balanceOf(user);
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        //  swap 15 for approx 15
        assertApproxEqAbs(1542134089740859, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_debt_all_out() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToLeverage = 20.0e18;
        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutSingle(assetFrom, borrowAsset);
        uint256 maxIn = 0.01e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapAllOut.selector, maxIn, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, maxIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        // no debt left
        uint256 debtBalanceFinal = IERC20All(debtAsset).balanceOf(user);
        assertApproxEqAbs(debtBalanceFinal, 0, 0);

        balance = balance - debtBalanceFinal;
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        assertApproxEqAbs(8347318762672509, balanceFrom, 1);
        assertApproxEqAbs(amountToLeverage, balance, 1);
    }

    /** TEST V2 CALLBACKS */

    function test_margin_mantle_debt_exact_in_v2() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactInSingleV2(assetFrom, borrowAsset);
        uint256 amountIn = 0.001e18;
        uint256 minimumOut = 1.7e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(debtAsset).balanceOf(user);
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(2395237686677368449, balance, 1);
    }

    function test_margin_mantle_debt_exact_in_multi_v2() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactInMultiV2(assetFrom, borrowAsset);
        uint256 amountIn = 0.001e18;
        uint256 minimumOut = 1.7e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountIn, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, amountIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(debtAsset).balanceOf(user);
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        //  swap 15 for approx 15
        assertApproxEqAbs(amountIn, balanceFrom, 1);
        assertApproxEqAbs(2391067037304473942, balance, 1);
    }

    function test_margin_mantle_debt_exact_out_v2() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutSingleV2(assetFrom, borrowAsset);
        uint256 amountOut = 2.7e18;
        uint256 maxIn = 0.002e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, maxIn, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, maxIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(debtAsset).balanceOf(user);
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        //  swap 15 for approx 15
        assertApproxEqAbs(1127237279688107, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_debt_exact_out_multi_v2() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutMultiV2(assetFrom, borrowAsset);
        uint256 amountOut = 3.7e18;
        uint256 maxIn = 0.004e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactOut.selector, amountOut, maxIn, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, maxIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(debtAsset).balanceOf(user);
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        //  swap 15 for approx 15
        assertApproxEqAbs(1547430747140979, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_debt_all_out_v2() external {
        uint8 lenderId = DEFAULT_LENDER;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToLeverage = 20.0e18;
        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutSingleV2(assetFrom, borrowAsset);
        uint256 maxIn = 0.01e18;
        calls[0] = abi.encodeWithSelector(IFlashAggregator.flashSwapAllOut.selector, maxIn, swapPath);

        vm.prank(user);
        IERC20All(debtAssetFrom).approveDelegation(brokerProxyAddress, maxIn);

        uint256 balanceFrom = IERC20All(debtAssetFrom).balanceOf(user);
        uint256 balance = IERC20All(debtAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        // no debt left
        uint256 debtBalanceFinal = IERC20All(debtAsset).balanceOf(user);
        assertApproxEqAbs(debtBalanceFinal, 0, 0);

        balance = balance - debtBalanceFinal;
        balanceFrom = IERC20All(debtAssetFrom).balanceOf(user) - balanceFrom;

        assertApproxEqAbs(8350118923485992, balanceFrom, 1);
        assertApproxEqAbs(amountToLeverage, balance, 1);
    }
}