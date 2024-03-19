// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginDebtSwapTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_debt_exact_in(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactInSingle(assetFrom, borrowAsset, lenderId);
        uint256 amountIn = 0.001e18;
        uint256 minimumOut = 3.7e18;
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
        assertApproxEqAbs(3755753147829134432, balance, 1);
    }

    function test_margin_mantle_debt_exact_in_multi(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactInMulti(assetFrom, borrowAsset, lenderId);
        uint256 amountIn = 0.001e18;
        uint256 minimumOut = 3.7e18;
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
        assertApproxEqAbs(3741566099564202243, balance, 1);
    }

    function test_margin_mantle_debt_exact_out(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutSingle(assetFrom, borrowAsset, lenderId);
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
        assertApproxEqAbs(985153928191580, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_debt_exact_out_multi(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutMulti(assetFrom, borrowAsset, lenderId);
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
        assertApproxEqAbs(988890229117376, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_debt_all_out(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToLeverage = 30.0e18;
        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutSingle(assetFrom, borrowAsset, lenderId);
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

        assertApproxEqAbs(7992863431647291, balanceFrom, 1);
        assertApproxEqAbs(amountToLeverage, balance, 1);
    }

    /** TEST V2 CALLBACKS */

    function test_margin_mantle_debt_exact_in_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactInSingleV2(assetFrom, borrowAsset, lenderId);
        uint256 amountIn = 0.001e18;
        uint256 minimumOut = 3.7e18;
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
        assertApproxEqAbs(3742924451815735880, balance, 1);
    }

    function test_margin_mantle_debt_exact_in_multi_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactInMultiV2(assetFrom, borrowAsset, lenderId);
        uint256 amountIn = 0.001e18;
        uint256 minimumOut = 3.7e18;
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
        assertApproxEqAbs(3742127048135549684, balance, 1);
    }

    function test_margin_mantle_debt_exact_out_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutSingleV2(assetFrom, borrowAsset, lenderId);
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
        assertApproxEqAbs(988531749237808, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_debt_exact_out_multi_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 30.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutMultiV2(assetFrom, borrowAsset, lenderId);
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
        assertApproxEqAbs(988742419702295, balanceFrom, 1);
        assertApproxEqAbs(amountOut, balance, 1);
    }

    function test_margin_mantle_debt_all_out_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 3);
        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToLeverage = 30.0e18;
        {
            address asset = USDC;
            uint256 amountToDeposit = 10.0e6;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        address assetFrom = WETH;
        address debtAssetFrom = debtTokens[assetFrom][lenderId];

        bytes[] memory calls = new bytes[](1);

        bytes memory swapPath = getDebtSwapExactOutSingleV2(assetFrom, borrowAsset, lenderId);
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

        assertApproxEqAbs(8015579404741637, balanceFrom, 1);
        assertApproxEqAbs(amountToLeverage, balance, 1);
    }
}
