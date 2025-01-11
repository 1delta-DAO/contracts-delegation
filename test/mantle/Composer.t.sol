// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";

contract ComposerTestMantle is DeltaSetup {
    function test_mantle_composer_depo() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = users[index];
            uint256 amount = 10.0e6;
            deal(TokensMantle.USDT, user, 1e23);

            vm.prank(user);
            IERC20All(TokensMantle.USDT).approve(address(brokerProxyAddress), amount);

            bytes memory transfer = transferIn(
                TokensMantle.USDT,
                brokerProxyAddress,
                amount //
            );
            bytes memory data = deposit(
                TokensMantle.USDT,
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
    }

    function test_mantle_composer_borrow() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = users[index];
            uint256 amount = 10.0e6;
            address asset = TokensMantle.USDT;

            _deposit(asset, user, amount, lenderId);

            vm.prank(user);
            IERC20All(asset).approve(address(brokerProxyAddress), amount);

            uint256 borrowAmount = 5.0e6;

            address borrowAsset = TokensMantle.USDC;
            vm.prank(user);
            IERC20All(debtTokens[borrowAsset][lenderId]).approveDelegation(
                address(brokerProxyAddress), //
                borrowAmount
            );

            bytes memory data = borrow(borrowAsset, user, borrowAmount, lenderId, DEFAULT_MODE);
            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas", gas);
        }
    }

    function test_mantle_composer_repay() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = users[index];

            uint256 amount = 10.0e6;
            address asset = TokensMantle.USDT;

            uint256 borrowAmount = 5.0e6;
            address borrowAsset = TokensMantle.USDC;

            _deposit(asset, user, amount, lenderId);

            _borrow(borrowAsset, user, borrowAmount, lenderId);

            uint256 repayAmount = 2.50e6;

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
        }
    }

    function test_mantle_composer_repay_too_much() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = users[index];

            uint256 amount = 10.0e6;
            address asset = TokensMantle.USDT;

            uint256 borrowAmount = 5.0e6;
            address borrowAsset = TokensMantle.USDC;

            _deposit(asset, user, amount, lenderId);

            _borrow(borrowAsset, user, borrowAmount, lenderId);

            uint256 repayAmount = 12.50e6;
            deal(borrowAsset, user, repayAmount);
            bytes memory transfer = transferIn(
                borrowAsset,
                brokerProxyAddress,
                repayAmount //
            );
            bytes memory data = repay(
                borrowAsset,
                user,
                0,
                lenderId, //
                DEFAULT_MODE
            );
            data = abi.encodePacked(transfer, data, sweep(borrowAsset, user, 0, SweepType.VALIDATE));

            vm.prank(user);
            IERC20All(borrowAsset).approve(address(brokerProxyAddress), repayAmount);

            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas", gas);

            console.log(IERC20All(borrowAsset).balanceOf(user));
        }
    }

    function test_mantle_composer_withdraw() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = users[index];

            uint256 amount = 10.0e6;
            address asset = TokensMantle.USDT;

            _deposit(asset, user, amount, lenderId);

            uint256 withdrawAmount = 2.50e6;

            bytes memory data = withdraw(asset, user, withdrawAmount, lenderId);

            vm.prank(user);
            IERC20All(collateralTokens[asset][lenderId]).approve(address(brokerProxyAddress), withdrawAmount);

            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas", gas);
        }
    }

    function test_mantle_composer_withdraw_all() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = users[index];

            uint256 amount = 10.0e6;
            address asset = TokensMantle.USDT;

            _deposit(asset, user, amount, lenderId);

            uint256 withdrawAmount = type(uint112).max;

            bytes memory data = withdraw(asset, user, withdrawAmount, lenderId);

            vm.prank(user);
            IERC20All(collateralTokens[asset][lenderId]).approve(address(brokerProxyAddress), withdrawAmount);

            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas", gas);

            assert(IERC20All(collateralTokens[asset][lenderId]).balanceOf(user) == 0);
        }
    }

    function test_mantle_composer_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = TokensMantle.USDC;
        address assetOut = TokensMantle.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.AGNI,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.FUSION_X,
            DEX_FEE_STABLES //
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

    function getWNativeToToken()
        internal
        pure
        returns (
            address[] memory tks,
            uint8[] memory pids, //
            uint16[] memory fees
        )
    {
        tks = new address[](3);
        tks[0] = TokensMantle.WMNT;
        tks[1] = TokensMantle.METH;
        tks[2] = TokensMantle.WETH;
        fees = new uint16[](2);
        fees[0] = uint16(250);
        fees[1] = DEX_FEE_STABLES;
        pids = new uint8[](2);
        pids[0] = DexMappingsMantle.CLEOPATRA_CL;
        pids[1] = DexMappingsMantle.AGNI;
    }

    function getTokenToWNative()
        internal
        pure
        returns (
            address[] memory tks,
            uint8[] memory pids, //
            uint16[] memory fees
        )
    {
        tks = new address[](3);
        tks[0] = TokensMantle.WETH;
        tks[1] = TokensMantle.METH;
        tks[2] = TokensMantle.WMNT;
        fees = new uint16[](2);
        fees[0] = DEX_FEE_STABLES;
        fees[1] = uint16(250);
        pids = new uint8[](2);
        pids[0] = DexMappingsMantle.AGNI;
        pids[1] = DexMappingsMantle.CLEOPATRA_CL;
    }

    function test_mantle_composer_multi_route_exact_in_native() external {
        address user = testUser;
        uint256 amount = 4000.0e18;
        uint256 amountMin = 0.10e18;

        address assetIn = TokensMantle.WMNT;
        address assetOut = TokensMantle.WETH;
        vm.deal(user, amount);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.AGNI,
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getWNativeToToken();
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

    function test_mantle_composer_multi_route_exact_out_native_out() external {
        address user = testUser;
        uint256 amount = 4000.0e18;
        uint256 amountMax = 5.0e18;

        address assetIn = TokensMantle.WETH;
        address assetOut = TokensMantle.WMNT;
        deal(assetIn, user, amountMax);

        bytes memory dataAgni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.AGNI,
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getWNativeToToken();
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
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 1668753875334069967, 0);
    }

    function test_mantle_composer_multi_route_exact_out_native_in() external {
        address user = testUser;
        uint256 amount = 2.0e18;
        uint256 amountMax = 9000.0e18;

        address assetIn = TokensMantle.WMNT;
        address assetOut = TokensMantle.WETH;
        vm.deal(user, amountMax);

        bytes memory dataAgni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.AGNI,
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getTokenToWNative();
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
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 4825933262798723917376, 0);
    }

    function test_mantle_composer_multi_route_exact_in_native_out() external {
        address user = testUser;
        uint256 amount = 2.0e18;
        uint256 amountMin = 4000.0e18;

        address assetIn = TokensMantle.WETH;
        address assetOut = TokensMantle.WMNT;
        deal(assetIn, user, amount);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.AGNI,
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getTokenToWNative();
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

        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, 4791714389649651447685, 1);
        assertApproxEqAbs(balanceInBefore - balanceInAfter, amount, 0);
    }

    function test_mantle_composer_multi_route_exact_in_self() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = TokensMantle.USDC;
        address assetOut = TokensMantle.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.AGNI,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.FUSION_X,
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

    function test_mantle_composer_multi_route_exact_out() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 maxIn = 1040.0e6;

        address assetIn = TokensMantle.USDC;
        address assetOut = TokensMantle.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.AGNI,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsMantle.FUSION_X,
            DEX_FEE_STABLES //
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

    function _borrow(address borrowAsset, address user, uint256 borrowAmount, uint16 lenderId) internal {
        vm.prank(user);
        IERC20All(debtTokens[borrowAsset][lenderId]).approveDelegation(
            address(brokerProxyAddress), //
            borrowAmount
        );

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
