// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// solhint-disable max-line-length

import "../../contracts/1delta/modules/shared/Commands.sol";
import "../shared/interfaces/ICurvePool.sol";
import "./DeltaSetup.f.sol";

contract ComposerTestPolygon is DeltaSetup {
    function test_polygon_composer_depo(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && compoundUSDCEOrAave(lenderId));
        uint256 amount = 10.0e6;
        address asset = TokensPolygon.WMATIC;
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

    function test_polygon_composer_depo_comet() external {
        address user = testUser;
        uint16 lenderId = LenderMappingsPolygon.COMPOUND_V3_USDCE;
        // vm.assume(user != address(0) && (lenderId == 50));
        uint256 amount = 0.000000001e18;
        address asset = TokensPolygon.WETH;
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

    function test_polygon_composer_borrow(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && compoundUSDCEOrAave(lenderId));
        uint256 amount = 500.0e18;
        address asset = TokensPolygon.WMATIC;

        _deposit(asset, user, amount, lenderId);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        uint256 borrowAmount = 100.0e6;

        address borrowAsset = TokensPolygon.USDC;
        approveBorrowDelegation(user, borrowAsset, borrowAmount, lenderId);

        bytes memory data = borrow(borrowAsset, user, borrowAmount, lenderId, DEFAULT_MODE);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assertApproxEqAbs(borrowAmount, getBorrowBalance(user, borrowAsset, lenderId), 1);
    }

    function test_polygon_composer_repay(uint16 lenderId) external {
        address user = testUser;

        vm.assume(user != address(0) && compoundUSDCEOrAave(lenderId));

        uint256 amount = 500.0e18;
        address asset = TokensPolygon.WMATIC;

        uint256 borrowAmount = 100.0e6;
        address borrowAsset = TokensPolygon.USDC;

        _deposit(asset, user, amount, lenderId);

        _borrow(borrowAsset, user, borrowAmount, lenderId);

        uint256 repayAmount = 20.50e6;

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

    function test_polygon_composer_repay_too_much(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && compoundUSDCEOrAave(lenderId));

        uint256 amount = 500.0e18;
        address asset = TokensPolygon.WMATIC;

        uint256 borrowAmount = 100.0e6;
        address borrowAsset = TokensPolygon.USDC;

        _deposit(asset, user, amount, lenderId);

        _borrow(borrowAsset, user, borrowAmount, lenderId);

        uint256 repayAmount = 120.50e6;
        deal(borrowAsset, user, repayAmount);
        bytes memory transfer = transferIn(
            borrowAsset,
            brokerProxyAddress,
            repayAmount //
        );
        bytes memory data = repay(
            borrowAsset,
            user,
            lenderId >= LenderMappingsPolygon.MAX_AAVE_V2_ID ? type(uint112).max : repayAmount,
            lenderId, //
            DEFAULT_MODE
        );
        data = abi.encodePacked(transfer, data, sweep(borrowAsset, user, lenderId, SweepType.VALIDATE));

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(brokerProxyAddress), repayAmount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        console.log(IERC20All(borrowAsset).balanceOf(user));
    }

    function test_polygon_composer_withdraw() external {
        uint16 lenderId = LenderMappingsPolygon.COMPOUND_V3_USDCE;
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amount = 10.0e18;
        address asset = TokensPolygon.WMATIC;

        _deposit(asset, user, amount, lenderId);

        uint256 withdrawAmount = 2.50e18;

        bytes memory data = withdraw(asset, user, withdrawAmount, lenderId);
        approveWithdrawal(user, asset, withdrawAmount, lenderId);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        assertApproxEqAbs(amount - withdrawAmount, getCollateralBalance(user, asset, lenderId), 2);
    }

    function test_polygon_composer_withdraw_all(uint16 lenderId) external {
        address user = testUser;

        vm.assume(user != address(0) && compoundUSDCEOrAave(lenderId));

        uint256 amount = 500.0e18;
        address asset = TokensPolygon.WMATIC;

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

    function test_polygon_composer_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = TokensPolygon.USDC;
        address assetOut = TokensPolygon.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.UNI_V3,
            uint16(DEX_FEE_STABLES) //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.SUSHI_V3,
            uint16(DEX_FEE_STABLES) //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, false, dataAgni.length),
            dataAgni,
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

    function getNativeToToken()
        internal
        pure
        returns (
            address[] memory tks,
            uint8[] memory pids, //
            uint16[] memory fees
        )
    {
        tks = new address[](3);
        tks[0] = TokensPolygon.WMATIC;
        tks[1] = TokensPolygon.USDC;
        tks[2] = TokensPolygon.WETH;
        fees = new uint16[](2);
        fees[0] = uint16(500);
        fees[1] = uint16(500);
        pids = new uint8[](2);
        pids[0] = DexMappingsPolygon.SUSHI_V3;
        pids[1] = DexMappingsPolygon.UNI_V3;
    }

    function getTokenToNative()
        internal
        pure
        returns (
            address[] memory tks,
            uint8[] memory pids, //
            uint16[] memory fees
        )
    {
        tks = new address[](3);
        tks[0] = TokensPolygon.WETH;
        tks[1] = TokensPolygon.USDC;
        tks[2] = TokensPolygon.WMATIC;
        fees = new uint16[](2);
        fees[0] = uint16(500);
        fees[1] = uint16(500);
        pids = new uint8[](2);
        pids[0] = DexMappingsPolygon.UNI_V3;
        pids[1] = DexMappingsPolygon.SUSHI_V3;
    }

    function test_polygon_composer_multi_route_exact_in_native() external {
        address user = testUser;
        uint256 amount = 4000.0e18;
        uint256 amountMin = 0.10e18;

        address assetIn = TokensPolygon.WMATIC;
        address assetOut = TokensPolygon.WETH;
        vm.deal(user, amount);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.UNI_V3,
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getNativeToToken();
            dataFusion = getSpotExactInMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, true, dataAgni.length),
            dataAgni,
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, true, dataFusion.length),
            dataFusion //
        );

        data = abi.encodePacked(wrap(amount), data);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose{value: amount}(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_polygon_composer_multi_route_exact_out_native_out() external {
        address user = testUser;
        uint256 amount = 4000.0e18;
        uint256 amountMax = 7.0e18;

        address assetIn = TokensPolygon.WETH;
        address assetOut = TokensPolygon.WMATIC;
        deal(assetIn, user, amountMax);

        bytes memory dataAgni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.UNI_V3,
            uint16(500) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getNativeToToken();
            dataFusion = getSpotExactOutMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            brokerProxyAddress,
            encodeSwapAmountParams(amount / 2, amountMax / 2, false, dataAgni.length),
            dataAgni,
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
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 665692566352012255, 0);
    }

    function test_polygon_composer_multi_route_exact_out_native_in() external {
        address user = testUser;
        uint256 amount = 1.0e18;
        uint256 amountMax = 7500.0e18;

        address assetIn = TokensPolygon.WMATIC;
        address assetOut = TokensPolygon.WETH;
        vm.deal(user, amountMax);

        bytes memory dataAgni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.UNI_V3,
            uint16(500) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getTokenToNative();
            dataFusion = getSpotExactOutMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount / 2, amountMax / 2, true, dataAgni.length),
            dataAgni,
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
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 6303318979812611491310, 0);
    }

    function test_polygon_composer_multi_route_exact_in_native_out() external {
        address user = testUser;
        uint256 amount = 2.0e18;
        uint256 amountMin = 4000.0e18;

        address assetIn = TokensPolygon.WETH;
        address assetOut = TokensPolygon.WMATIC;
        deal(assetIn, user, amount);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.UNI_V3,
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getTokenToNative();
            dataFusion = getSpotExactInMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            brokerProxyAddress,
            encodeSwapAmountParams(amount / 2, 0, false, dataAgni.length),
            dataAgni,
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

        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, 11668752556768511510064, 1);
        assertApproxEqAbs(balanceInBefore - balanceInAfter, amount, 0);
    }

    function test_polygon_composer_multi_route_exact_in_self() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = TokensPolygon.USDC;
        address assetOut = TokensPolygon.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.UNI_V3,
            uint16(DEX_FEE_STABLES) //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.SUSHI_V3,
            uint16(DEX_FEE_STABLES) //
        );

        bytes memory transfer = transferIn(
            assetIn,
            brokerProxyAddress,
            amount //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, true, dataAgni.length),
            dataAgni,
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

    function test_polygon_composer_multi_route_exact_out() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 maxIn = 1140.0e6;

        address assetIn = TokensPolygon.USDC;
        address assetOut = TokensPolygon.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.UNI_V3,
            uint16(DEX_FEE_STABLES) //
        );
        bytes memory dataFusion = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.SUSHI_V3,
            uint16(DEX_FEE_STABLES) //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount / 2, maxIn, false, dataAgni.length),
            dataAgni,
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
            address pool = testQuoter.v3TypePool(tokens[i], tokens[i + 1], fees[i], pids[i]);
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
            address pool = testQuoter.v3TypePool(tokens[i], tokens[i + 1], fees[i], pids[i]);
            data = abi.encodePacked(data, actions[i], pids[i], pool, fees[i], tokens[i + 1]);
        }
        return abi.encodePacked(data, uint8(99));
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        uint8 action = 0;
        return abi.encodePacked(tokenOut, action, poolId, pool, fee, tokenIn, uint8(99));
    }

    function _deposit(address asset, address user, uint256 amount, uint16 lenderId) internal {
        deal(asset, user, amount);

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
    }

    function _borrow(address borrowAsset, address user, uint256 borrowAmount, uint16 lenderId) internal {
        approveBorrowDelegation(user, borrowAsset, borrowAmount, lenderId);

        bytes memory data = borrow(
            borrowAsset,
            user,
            borrowAmount,
            lenderId, //
            DEFAULT_MODE
        );

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }
}

// Ran 11 tests for test/mantle/Composer.t.sol:ComposerTest
// [PASS] test_polygon_composer_borrow() (gas: 917038)
// Logs:
//   gas 378730
//   gas 432645

// [PASS] test_polygon_composer_depo() (gas: 371016)
// Logs:
//   gas 248957

// [PASS] test_polygon_composer_multi_route_exact_in() (gas: 377134)
// Logs:
//   gas 192095

// [PASS] test_polygon_composer_multi_route_exact_in_native() (gas: 368206)
// Logs:
//   gas 374361

// [PASS] test_polygon_composer_multi_route_exact_in_native_out() (gas: 633199)
// Logs:
//   gas-exactIn-native-out-2 split 547586

// [PASS] test_polygon_composer_multi_route_exact_in_self() (gas: 399348)
// Logs:
//   gas 219240

// [PASS] test_polygon_composer_multi_route_exact_out() (gas: 390674)
// Logs:
//   gas 190957

// [PASS] test_polygon_composer_multi_route_exact_out_native_in() (gas: 408213)
// Logs:
//   gas-exactOut-native-in-2 split 385726

// [PASS] test_polygon_composer_multi_route_exact_out_native_out() (gas: 558685)
// Logs:
//   gas-exactOut-native-out-2 split 413439

// [PASS] test_polygon_composer_repay() (gas: 985744)
// Logs:
//   gas 378730
//   gas 432646
//   gas 102301

// [PASS] test_polygon_composer_withdraw() (gas: 702003)
// Logs:
//   gas 378730
//   gas 253948

// Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 319.97ms (40.41ms CPU time)
