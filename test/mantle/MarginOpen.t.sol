// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginOpenTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_open_exact_in(uint8 lenderId) external /** address user, uint8 lenderId */ {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDC;

            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;

            uint256 amountToBorrow = 20.0e18;
            uint256 minimumOut = 10.0e6;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToBorrow,
                minimumOut, //
                lenderId
            );
        }
        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        openExactIn(
            user,
            params.collateralAsset,
            params.borrowAsset,
            params.amountToDeposit,
            params.swapAmount,
            params.checkAmount,
            getOpenExactInSingle(params.borrowAsset, params.collateralAsset, lenderId),
            lenderId
        );

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39122533, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, params.amountToDeposit + params.swapAmount, 1.0e8);
    }

    function test_margin_mantle_open_exact_in_izi(uint8 lenderId) external /** address user, uint8 lenderId */ {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDT;

            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;

            uint256 amountToBorrow = 20.0e18;
            uint256 minimumOut = 10.0e6;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToBorrow,
                minimumOut, //
                lenderId
            );
        }
        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        openExactIn(
            user,
            params.collateralAsset,
            params.borrowAsset,
            params.amountToDeposit,
            params.swapAmount,
            params.checkAmount,
            getOpenExactInSingle_izi(params.borrowAsset, params.collateralAsset, lenderId),
            lenderId
        );

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39850074, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, params.amountToDeposit + params.swapAmount, 1.0e8);
    }

    function test_margin_mantle_open_exact_in_multi(uint8 lenderId) external /** address user, uint8 lenderId */ {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDC;

            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;

            uint256 amountToBorrow = 20.0e18;
            uint256 minimumOut = 10.0e6;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToBorrow,
                minimumOut, //
                lenderId
            );
        }
        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        openExactIn(
            user,
            params.collateralAsset,
            params.borrowAsset,
            params.amountToDeposit,
            params.swapAmount,
            params.checkAmount,
            getOpenExactInMulti(params.borrowAsset, params.collateralAsset, lenderId),
            lenderId
        );

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(38642840, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, params.amountToDeposit + params.swapAmount, 1.0e8);
    }

    function test_margin_mantle_open_exact_out(uint8 lenderId) external {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDC;
            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;
            uint256 amountToReceive = 30.0e6;
            uint256 maximumIn = 29.0e18;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToReceive,
                maximumIn, //
                lenderId
            );
        }

        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        openExactOut(
            user,
            params.collateralAsset,
            params.borrowAsset,
            params.amountToDeposit,
            params.swapAmount,
            params.checkAmount,
            getOpenExactOutSingle(params.borrowAsset, params.collateralAsset, lenderId),
            lenderId
        );

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(20621357675549497673, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, params.amountToDeposit + params.swapAmount, 0);
    }

    function test_margin_mantle_open_exact_out_multi(uint8 lenderId) external {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDC;
            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;
            uint256 amountToReceive = 30.0e6;
            uint256 maximumIn = 29.0e18;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToReceive,
                maximumIn, //
                lenderId
            );
        }

        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        openExactOut(
            user,
            params.collateralAsset,
            params.borrowAsset,
            params.amountToDeposit,
            params.swapAmount,
            params.checkAmount,
            getOpenExactOutMulti(params.borrowAsset, params.collateralAsset, lenderId),
            lenderId
        );

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(20980519129019992249, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, params.amountToDeposit + params.swapAmount, 0);
    }

    /** THE FOLLOWING TESTS CHECK THE CALLBACK FOR V2 */

    function test_margin_mantle_open_exact_in_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDC;

            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;

            uint256 amountToBorrow = 20.0e18;
            uint256 minimumOut = 10.0e6;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToBorrow,
                minimumOut, //
                lenderId
            );
        }
        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        openExactIn(
            user,
            params.collateralAsset,
            params.borrowAsset,
            params.amountToDeposit,
            params.swapAmount,
            params.checkAmount,
            getOpenExactInSingleV2(params.borrowAsset, params.collateralAsset, lenderId),
            lenderId
        );

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39923752, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, params.amountToDeposit + params.swapAmount, 1.0e8);
    }

    function test_margin_mantle_open_exact_in_multi_v2(uint8 lenderId) external /** address user, uint8 lenderId */ {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDC;

            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;

            uint256 amountToBorrow = 20.0e18;
            uint256 minimumOut = 10.0e6;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToBorrow,
                minimumOut, //
                lenderId
            );
        }
        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        openExactIn(
            user,
            params.collateralAsset,
            params.borrowAsset,
            params.amountToDeposit,
            params.swapAmount,
            params.checkAmount,
            getOpenExactInMultiV2(params.borrowAsset, params.collateralAsset, lenderId),
            lenderId
        );

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39897880, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, params.amountToDeposit + params.swapAmount, 1.0e8);
    }

    function test_margin_mantle_open_exact_out_v2(uint8 lenderId) external {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDC;
            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;
            uint256 amountToReceive = 30.0e6;
            uint256 maximumIn = 29.0e18;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToReceive,
                maximumIn, //
                lenderId
            );
        }

        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        openExactOut(
            user,
            params.collateralAsset,
            params.borrowAsset,
            params.amountToDeposit,
            params.swapAmount,
            params.checkAmount,
            getOpenExactOutSingleV2(params.borrowAsset, params.collateralAsset, lenderId),
            lenderId
        );

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(20050966249736894241, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, params.amountToDeposit + params.swapAmount, 0);
    }

    function test_margin_mantle_open_exact_out_multi_v2(uint8 lenderId) external {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDC;
            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;
            uint256 amountToReceive = 30.0e6;
            uint256 maximumIn = 29.0e18;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToReceive,
                maximumIn, //
                lenderId
            );
        }

        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        openExactOut(
            user,
            params.collateralAsset,
            params.borrowAsset,
            params.amountToDeposit,
            params.swapAmount,
            params.checkAmount,
            getOpenExactOutMultiV2(params.borrowAsset, params.collateralAsset, lenderId),
            lenderId
        );

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(20068321880954662893, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, params.amountToDeposit + params.swapAmount, 0);
    }
}
