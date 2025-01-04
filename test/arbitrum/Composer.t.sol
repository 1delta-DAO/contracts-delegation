// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "../shared/interfaces/ICurvePool.sol";
import "./DeltaSetup.f.sol";

contract ComposerTestArbitrum is DeltaSetup {
    function test_arbitrum_composer_depo(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && validAaveLender(lenderId));
        uint256 amount = 10.0e6;
        address asset = TokensArbitrum.USDC;
        deal(asset, user, 1e23);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = transferIn(
            asset,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = deposit(
            asset,
            user,
            amount,
            lenderId //
        );
        data = abi.encodePacked(transfer, data);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assertApproxEqAbs(amount, getCollateralBalance(user, asset, lenderId), 0);
    }

    function test_arbitrum_composer_depo_venus() external {
        uint16 lenderId = VENUS;
        address user = testUser;
        vm.assume(user != address(0) && validVenusLender(lenderId));
        uint256 amount = 10.0e6;
        address asset = TokensArbitrum.USDC;
        deal(asset, user, 1e23);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = transferIn(
            asset,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = deposit(
            asset,
            user,
            amount,
            lenderId //
        );
        data = abi.encodePacked(transfer, data);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assertApproxEqAbs(amount, getCollateralBalance(user, asset, lenderId), 1);
    }

    function test_arbitrum_composer_depo_comet() external {
        address user = testUser;
        uint16 lenderId = 2000;
        // vm.assume(user != address(0) && (lenderId == 50));
        uint256 amount = 0.000000001e18;
        address asset = TokensArbitrum.WETH;
        deal(asset, user, 1e23);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = transferIn(
            asset,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = deposit(
            asset,
            user,
            amount,
            lenderId //
        );
        data = abi.encodePacked(transfer, data);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assertApproxEqAbs(amount, getCollateralBalance(user, asset, lenderId), 0);
    }

    function test_arbitrum_composer_borrow(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && validAaveLender(lenderId));
        uint256 amount = 1.0e8;
        address asset = TokensArbitrum.WBTC;

        _deposit(asset, user, amount, lenderId);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        uint256 borrowAmount = 0.01e8;

        address borrowAsset = TokensArbitrum.WBTC;
        approveBorrowDelegation(user, borrowAsset, borrowAmount, lenderId);

        bytes memory data = borrow(borrowAsset, user, borrowAmount, lenderId, DEFAULT_MODE);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assertApproxEqAbs(borrowAmount, getBorrowBalance(user, borrowAsset, lenderId), 1);
    }

    function test_arbitrum_composer_borrow_venus() external {
        uint16 lenderId = VENUS;
        address user = testUser;
        vm.assume(user != address(0) && validVenusLender(lenderId));
        uint256 amount = 1.0e8;
        address asset = TokensArbitrum.WBTC;

        _deposit(asset, user, amount, lenderId);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        uint256 borrowAmount = 0.01e8;

        address borrowAsset = TokensArbitrum.WBTC;
        approveBorrowDelegation(user, borrowAsset, borrowAmount, lenderId);

        bytes memory data = borrow(borrowAsset, user, borrowAmount, lenderId, DEFAULT_MODE);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assertApproxEqAbs(borrowAmount, getBorrowBalance(user, borrowAsset, lenderId), 1);
    }

    function test_arbitrum_composer_repay(uint16 lenderId) external {
        address user = testUser;

        vm.assume(user != address(0) && validAaveLender(lenderId));

        uint256 amount = 1.0e8;
        address asset = TokensArbitrum.WBTC;

        uint256 borrowAmount = 0.01e8;
        address borrowAsset = TokensArbitrum.WBTC;

        _deposit(asset, user, amount, lenderId);

        _borrow(borrowAsset, user, borrowAmount, lenderId);

        uint256 repayAmount = 0.005e8;

        bytes memory transfer = transferIn(
            borrowAsset,
            brokerProxyAddress,
            repayAmount //
        );

        bytes memory data = repay(
            borrowAsset,
            user,
            repayAmount,
            lenderId, //
            DEFAULT_MODE
        );
        data = abi.encodePacked(transfer, data);

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(brokerProxyAddress), repayAmount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assertApproxEqAbs(borrowAmount - repayAmount, getBorrowBalance(user, borrowAsset, lenderId), 2);
    }

    function test_arbitrum_composer_repay_too_much(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && validAaveLender(lenderId));

        uint256 amount = 1.0e8;
        address asset = TokensArbitrum.WBTC;

        uint256 borrowAmount = 0.01e8;
        address borrowAsset = TokensArbitrum.WBTC;

        _deposit(asset, user, amount, lenderId);

        _borrow(borrowAsset, user, borrowAmount, lenderId);

        uint256 repayAmount = 0.015e8;
        deal(borrowAsset, user, repayAmount);
        bytes memory transfer = transferIn(
            borrowAsset,
            brokerProxyAddress,
            repayAmount //
        );
        bytes memory data = repay(
            borrowAsset,
            user,
            repayAmount,
            lenderId, //
            DEFAULT_MODE
        );
        data = abi.encodePacked(transfer, data, sweep(borrowAsset, user, lenderId, SweepType.VALIDATE));

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(brokerProxyAddress), repayAmount);

        uint256 borrowAssetBalance = IERC20All(borrowAsset).balanceOf(user);

        {
            uint gas = gasleft();
            vm.prank(user);
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas", gas);
        }
        uint256 borrowAssetBalanceAfter = IERC20All(borrowAsset).balanceOf(user);

        assertApproxEqAbs(borrowAmount, borrowAssetBalance - borrowAssetBalanceAfter, 1);
        assertApproxEqAbs(0, getBorrowBalance(user, borrowAsset, lenderId), 0);
    }

    function test_arbitrum_composer_repay_too_much_venus() external {
        uint16 lenderId = VENUS;
        address user = testUser;
        vm.assume(user != address(0) && validVenusLender(lenderId));

        uint256 amount = 1.0e18;
        address asset = TokensArbitrum.WETH;

        uint256 borrowAmount = 0.01e18;
        address borrowAsset = TokensArbitrum.WETH;

        _deposit(asset, user, amount, lenderId);

        _borrow(borrowAsset, user, borrowAmount, lenderId);

        uint256 repayAmount = 0.015e18;
        deal(borrowAsset, user, repayAmount);
        bytes memory transfer = transferIn(
            borrowAsset,
            brokerProxyAddress,
            repayAmount //
        );
        bytes memory data = repay(
            borrowAsset,
            user,
            repayAmount,
            lenderId, //
            DEFAULT_MODE
        );
        data = abi.encodePacked(transfer, data, sweep(borrowAsset, user, lenderId, SweepType.VALIDATE));

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(brokerProxyAddress), repayAmount);

        uint256 borrowAssetBalance = IERC20All(borrowAsset).balanceOf(user);

        {
            uint gas = gasleft();
            vm.prank(user);
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas", gas);
        }
        uint256 borrowAssetBalanceAfter = IERC20All(borrowAsset).balanceOf(user);

        assertApproxEqAbs(borrowAmount, borrowAssetBalance - borrowAssetBalanceAfter, 0);
        assertApproxEqAbs(0, getBorrowBalance(user, borrowAsset, lenderId), 0);
    }

    function test_arbitrum_composer_withdraw(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && (validAaveLender(lenderId) || lenderId == COMPOUND_V3_USDC || lenderId == VENUS));

        uint256 amount = 10.0e6;
        address asset = TokensArbitrum.USDC;

        _deposit(asset, user, amount, lenderId);

        uint256 withdrawAmount = 5.0e6;

        bytes memory data = withdraw(asset, user, withdrawAmount, lenderId);
        approveWithdrawal(user, asset, withdrawAmount, lenderId);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        assertApproxEqAbs(amount - withdrawAmount, getCollateralBalance(user, asset, lenderId), 4);
    }

    function test_arbitrum_composer_withdraw_all(uint16 lenderId) external {
        address user = testUser;

        vm.assume(user != address(0) && (validAaveLender(lenderId) || lenderId == VENUS));

        uint256 amount = 500.0e6;
        address asset = TokensArbitrum.USDC;

        _deposit(asset, user, amount, lenderId);

        uint256 withdrawAmount = type(uint112).max;

        bytes memory data = withdraw(asset, user, withdrawAmount, lenderId);
        approveWithdrawal(user, asset, withdrawAmount, lenderId);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assertApproxEqAbs(0, getCollateralBalance(user, asset, lenderId), 2);
    }

    function test_arbitrum_composer_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = TokensArbitrum.USDC;
        address assetOut = TokensArbitrum.USDT;
        deal(assetIn, user, 1e23);

        bytes memory swapData = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            UNI_V3,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            SUSHI_V3,
            DEX_FEE_STABLES //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, false, swapData.length),
            swapData,
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, false, dataFusion.length),
            dataFusion //
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function getDollarToWeth()
        internal
        view
        returns (
            address[] memory tks,
            uint8[] memory pids, //
            uint16[] memory fees
        )
    {
        tks = new address[](3);
        tks[0] = TokensArbitrum.USDC;
        tks[1] = TokensArbitrum.USDT;
        tks[2] = TokensArbitrum.WETH;
        fees = new uint16[](2);
        fees[0] = 100;
        fees[1] = 0;
        pids = new uint8[](2);
        pids[0] = PANCAKE;
        pids[1] = ALGEBRA;
    }

    function getWethToDollar()
        internal
        view
        returns (
            address[] memory tks,
            uint8[] memory pids, //
            uint16[] memory fees
        )
    {
        tks = new address[](3);
        tks[0] = TokensArbitrum.WETH;
        tks[1] = TokensArbitrum.USDT;
        tks[2] = TokensArbitrum.USDC;
        fees = new uint16[](2);
        fees[0] = 0;
        fees[1] = 100;
        pids = new uint8[](2);
        pids[0] = ALGEBRA;
        pids[1] = PANCAKE;
    }

    function test_arbitrum_composer_multi_route_exact_in_native() external {
        address user = testUser;
        uint256 amount = 1.0e18;
        uint256 amountMin = 3300.0e6;

        address assetIn = TokensArbitrum.WETH;
        address assetOut = TokensArbitrum.USDC;
        vm.deal(user, amount);

        bytes memory swapData = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            PANCAKE,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getWethToDollar();
            dataFusion = getSpotExactInMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin / 2, true, swapData.length),
            swapData,
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin / 2, true, dataFusion.length),
            dataFusion //
        );

        data = abi.encodePacked(wrap(amount), data);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose{value: amount}(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_arbitrum_composer_multi_route_exact_out_native_out() external {
        address user = testUser;
        uint256 amount = 1.0e18;
        uint256 amountMax = 3800.0e6;

        address assetIn = TokensArbitrum.USDC;
        address assetOut = TokensArbitrum.WETH;
        deal(assetIn, user, amountMax);

        bytes memory swapData = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            PANCAKE,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getWethToDollar();
            dataFusion = getSpotExactOutMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            brokerProxyAddress,
            encodeSwapAmountParams(amount / 2, amountMax / 2, false, swapData.length),
            swapData,
            uint8(Commands.SWAP_EXACT_OUT),
            brokerProxyAddress,
            encodeSwapAmountParams(amount / 2, amountMax / 2, false, dataFusion.length),
            dataFusion //
        );

        data = abi.encodePacked(data, unwrap(user, amount, ComposerUtils.SweepType.VALIDATE));

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountMax);

        uint balanceOutBefore = user.balance;
        uint balanceInBefore = IERC20All(assetIn).balanceOf(user);
        {
            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas-exactOut-native-out-2 split", gas);
        }
        uint balanceOutAfter = user.balance;
        uint balanceInAfter = IERC20All(assetIn).balanceOf(user);

        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, amount, 1);
        // expect to pay 3.3k USDC for 1 ETH
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 3327215843, 0);
    }

    function test_arbitrum_composer_multi_route_exact_out_native_in() external {
        address user = testUser;
        uint256 amount = 3500.0e6;
        uint256 amountMax = 1.1e18;

        address assetIn = TokensArbitrum.WETH;
        address assetOut = TokensArbitrum.USDC;
        vm.deal(user, amountMax);

        bytes memory swapData = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            PANCAKE,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getDollarToWeth();
            dataFusion = getSpotExactOutMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount / 2, amountMax / 2, true, swapData.length),
            swapData,
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount / 2, amountMax / 2, true, dataFusion.length),
            dataFusion //
        );

        data = abi.encodePacked(wrap(amountMax), data, unwrap(user, 0, ComposerUtils.SweepType.VALIDATE));

        uint balanceOutBefore = IERC20All(assetOut).balanceOf(user);
        uint balanceInBefore = user.balance;
        {
            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose{value: amountMax}(data);
            gas = gas - gasleft();
            console.log("gas-exactOut-native-in-2 split", gas);
        }
        uint balanceOutAfter = IERC20All(assetOut).balanceOf(user);
        uint balanceInAfter = user.balance;

        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, amount, 1);
        // expect to pay 1.05 ETH for 3.5k USDC
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 1053014567802286149, 0);
    }

    function test_arbitrum_composer_multi_route_exact_in_native_out() external {
        address user = testUser;
        uint256 amount = 3500.0e6;
        uint256 amountMin = 1.0e18;

        address assetIn = TokensArbitrum.USDC;
        address assetOut = TokensArbitrum.WETH;
        deal(assetIn, user, amount);

        bytes memory swapData = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            PANCAKE,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getDollarToWeth();
            dataFusion = getSpotExactInMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            brokerProxyAddress,
            encodeSwapAmountParams(amount / 2, 0, false, swapData.length),
            swapData,
            uint8(Commands.SWAP_EXACT_IN),
            brokerProxyAddress,
            encodeSwapAmountParams(amount / 2, 0, false, dataFusion.length),
            dataFusion
        );

        data = abi.encodePacked(data, unwrap(user, amountMin, ComposerUtils.SweepType.VALIDATE));

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amount);

        uint balanceOutBefore = user.balance;
        uint balanceInBefore = IERC20All(assetIn).balanceOf(user);
        {
            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas-exactIn-native-out-2 split", gas);
        }
        uint balanceOutAfter = user.balance;
        uint balanceInAfter = IERC20All(assetIn).balanceOf(user);

        // receive 1.05 ETH for 3.5k USDT
        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, 1051912572244652711, 1);
        assertApproxEqAbs(balanceInBefore - balanceInAfter, amount, 0);
    }

    function test_arbitrum_composer_multi_route_exact_in_self() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = TokensArbitrum.USDC;
        address assetOut = TokensArbitrum.USDT;
        deal(assetIn, user, 1e23);

        bytes memory swapData = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            UNI_V3,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            SUSHI_V3,
            DEX_FEE_STABLES //
        );

        bytes memory transfer = transferIn(
            assetIn,
            brokerProxyAddress,
            amount //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, true, swapData.length),
            swapData,
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, true, dataFusion.length),
            dataFusion
        );

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(abi.encodePacked(transfer, data));
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_arbitrum_composer_multi_route_exact_out() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 maxIn = 1140.0e6;

        address assetIn = TokensArbitrum.USDC;
        address assetOut = TokensArbitrum.USDT;
        deal(assetIn, user, 1e23);

        bytes memory swapData = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            UNI_V3,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            SUSHI_V3,
            DEX_FEE_STABLES //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount / 2, maxIn, false, swapData.length),
            swapData,
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount / 2, maxIn, false, dataFusion.length),
            dataFusion //
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function getSpotExactInMultiGen2(address[] memory tokens, uint8[] memory pids, uint16[] memory fees) internal view returns (bytes memory data) {
        uint8[] memory actions = new uint8[](pids.length);
        data = abi.encodePacked(tokens[0]);
        for (uint i; i < pids.length; i++) {
            address pool = testQuoter._v3TypePool(tokens[i], tokens[i + 1], fees[i], pids[i]);
            data = abi.encodePacked(
                data,
                actions[i], // action id
                pids[i], // dex identifier
                pool, // dex param 0
                fees[i], // dex param 1
                tokens[i + 1]
            );
        }
        return data;
    }

    function getSpotExactOutMultiGen2(address[] memory tokens, uint8[] memory pids, uint16[] memory fees) internal view returns (bytes memory data) {
        uint8[] memory actions = new uint8[](pids.length);
        data = abi.encodePacked(tokens[0]);
        for (uint i; i < pids.length; i++) {
            actions[i] = 0;
            address pool = testQuoter._v3TypePool(tokens[i], tokens[i + 1], fees[i], pids[i]);
            data = abi.encodePacked(data, actions[i], pids[i], pool, fees[i], tokens[i + 1]);
        }
        return abi.encodePacked(data, uint8(99));
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        uint8 action = 0;
        return abi.encodePacked(tokenOut, action, poolId, pool, fee, tokenIn, uint8(99));
    }
}
