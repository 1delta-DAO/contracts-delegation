// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginCloseTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_close_exact_in(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactInSingle(asset, borrowAsset, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 10.0e18;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(10439645077346007110, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_in_multi(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 1.0e6;
            uint256 amountToLeverage = 2.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactInMulti(asset, borrowAsset, lenderId);
        uint256 amountIn = 1.5e6;
        uint256 minimumOut = 0.9e18; // this one provides a bad swap rate

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(952522044675599421, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_out(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactOutSingle(asset, borrowAsset, lenderId);
        uint256 amountOut = 15.0e18;
        uint256 amountInMaximum = 25.0e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            amountOut, //
            amountInMaximum,
            false,
            swapPath
        );
        console.log("test");
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(21699993, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_out_multi(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactOutMulti(asset, borrowAsset, lenderId);
        uint256 amountOut = 1.0e18;
        uint256 amountInMaximum = 20.0e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            amountOut, //
            amountInMaximum,
            false,
            swapPath
        );

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(1580965, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    function test_margin_mantle_close_all_in(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountIn = 15.0e6;
        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;
            _deposit(asset, user, amountIn, lenderId);
            openSimple(user, USDT, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactInSingle(asset, borrowAsset, lenderId);

        uint256 minimumOut = 8.0e18;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, (amountIn * 101) / 100);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

       bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            0, // max
            minimumOut,
            false,
            swapPath
        );

console.log("------------a");
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        // debt as to be zero now
        uint256 finalbalance = IERC20All(collateralAsset).balanceOf(user);
        assertApproxEqAbs(finalbalance, 0, 0);

        balance = balance - finalbalance;
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(9839155325003132124, borrowBalance, 1);
    }

    function test_margin_mantle_close_all_out(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToLeverage = 20.0e18;

        {
            uint256 amountToDeposit = 10.0e6;
            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactOutSingle(asset, borrowAsset, lenderId);
        uint256 amountInMaximum = 35.0e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            0, // max
            amountInMaximum,
            false,
            swapPath
        );

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        // expect zero debt left
        uint256 borrowBalanceFinal = IERC20All(debtAsset).balanceOf(user);
        assertApproxEqAbs(0, borrowBalanceFinal, 1);

        // compute delta
        borrowBalance = borrowBalance - borrowBalanceFinal;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(29152125, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountToLeverage, borrowBalance, 1);
    }

    /** TESTS FOR THE V2 CALLBACKS */

    function test_margin_mantle_close_exact_in_v2(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactInSingleV2(asset, borrowAsset, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 8.0e18;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountIn, // 
            minimumOut,
            false,
            swapPath
        );

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(9963991004524402584, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_in_multi_v2(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactInMultiV2(asset, borrowAsset, lenderId);
        uint256 amountIn = 15.0e6;
        uint256 minimumOut = 9.0e18; // this one provides a bad swap rate

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountIn, // 
            minimumOut,
            false,
            swapPath
        );

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountIn, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(9912306024486705073, borrowBalance, 1);
    }

    function test_margin_mantle_close_exact_out_v2(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e18;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactOutSingleV2(asset, borrowAsset, lenderId);
        uint256 amountOut = 15.0e18;
        uint256 amountInMaximum = 23.0e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            amountOut, // 
            amountInMaximum,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(22581858, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    function test_margin_mantle_close_all_out_v2(uint8 lenderIndex) external {
        address user = testUser;
        vm.assume(user != address(0) && validLenderIndex(lenderIndex));
        uint16 lenderId = getLenderByIndex(lenderIndex);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToLeverage = 20.0e18;

        {
            uint256 amountToDeposit = 10.0e6;
            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        bytes memory swapPath = getCloseExactOutSingleV2(asset, borrowAsset, lenderId);
        uint256 amountInMaximum = 35.0e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            0, // max
            amountInMaximum,
            false,
            swapPath
        );

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        // expect zero debt left
        uint256 borrowBalanceFinal = IERC20All(debtAsset).balanceOf(user);
        assertApproxEqAbs(0, borrowBalanceFinal, 1);

        // compute delta
        borrowBalance = borrowBalance - borrowBalanceFinal;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(30109865, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountToLeverage, borrowBalance, 1);
    }
}
