// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// solhint-disable max-line-length

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";

contract ComposerTestTaiko is DeltaSetup {
    uint16[] lenderIds = [LenderMappingsTaiko.HANA_ID, LenderMappingsTaiko.MERIDIAN_ID, LenderMappingsTaiko.TAKOTAKO_ID];
    uint16[] extendedLenderIds = [
        LenderMappingsTaiko.HANA_ID,
        LenderMappingsTaiko.MERIDIAN_ID,
        LenderMappingsTaiko.TAKOTAKO_ID,
        LenderMappingsTaiko.AVALON_ID
    ];

    function getProperLenderAsset(uint16 lenderId, address origAsset) internal pure returns (address) {
        return lenderId == LenderMappingsTaiko.AVALON_ID ? TokensTaiko.SOLV_BTC : origAsset;
    }

    function setUp() public override {
        vm.createSelectFork({blockNumber: 536157, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});

        intitializeFullDelta();
    }

    function test_taiko_invalid_lender() external {
        uint16 lenderId = 10;
        address user = testUser;
        uint256 amount = 10.0e6;
        address assetIn = TokensTaiko.USDC;
        deal(assetIn, user, 1e23);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = transferIn(
            assetIn,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = deposit(
            assetIn,
            user,
            amount,
            lenderId //
        );
        data = abi.encodePacked(transfer, data);
        vm.startPrank(user);
        uint gas = gasleft();
        vm.expectRevert();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        vm.stopPrank();
    }

    function test_taiko_composer_depo() external {
        for (uint8 index = 0; index < extendedLenderIds.length; index++) {
            uint16 lenderId = extendedLenderIds[index];
            console.log("lenderId", lenderId);
            address user = testUser;
            uint256 amount = 10.0e6;
            address assetIn = getProperLenderAsset(lenderId, TokensTaiko.USDC);
            deal(assetIn, user, 1e23);

            vm.prank(user);
            IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

            bytes memory transfer = transferIn(
                assetIn,
                brokerProxyAddress,
                amount //
            );
            bytes memory data = deposit(
                assetIn,
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

    function test_taiko_composer_borrow() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = testUser;
            uint256 amount = 1e18;
            address asset = getProperLenderAsset(lenderId, TokensTaiko.WETH);

            _deposit(asset, user, amount, lenderId);

            uint256 borrowAmount = 5.0e6;

            address borrowAsset = getProperLenderAsset(lenderId, TokensTaiko.USDC);
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

    function test_taiko_composer_repay() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = testUser;

            uint256 amount = 1e18;
            address asset = TokensTaiko.WETH;

            uint256 borrowAmount = 5.0e6;
            address borrowAsset = TokensTaiko.USDC;

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

    function test_taiko_composer_repay_too_much() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = testUser;

            uint256 amount = 1e18;
            address asset = TokensTaiko.WETH;

            uint256 borrowAmount = 5.0e6;
            address borrowAsset = TokensTaiko.USDC;

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
                type(uint112).max,
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

    function test_taiko_composer_withdraw() external {
        for (uint8 index = 0; index < extendedLenderIds.length; index++) {
            uint16 lenderId = extendedLenderIds[index];
            address user = testUser;

            uint256 amount = 1e18;
            address asset = getProperLenderAsset(lenderId, TokensTaiko.WETH);

            _deposit(asset, user, amount, lenderId);

            uint256 withdrawAmount = 0.50e18;

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

    function test_taiko_composer_withdraw_all() external {
        for (uint8 index = 0; index < lenderIds.length; index++) {
            uint16 lenderId = lenderIds[index];
            address user = testUser;

            uint256 amount = 1e18;
            address asset = TokensTaiko.WETH;

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

    function test_taiko_composer_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 20.0e6;
        uint256 amountMin = 0.0005e18;

        address assetIn = TokensTaiko.USDC;
        address assetOut = TokensTaiko.WETH;
        deal(assetIn, user, 1e23);

        bytes memory dataUniswap = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.UNI_V3,
            DEX_FEE_LOW_HIGH //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.IZUMI,
            DEX_FEE_LOW_HIGH //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, false, dataUniswap.length),
            dataUniswap,
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, false, dataFusion.length),
            dataFusion //
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint received = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas, TokensTaiko.WETH);

        received = IERC20All(assetOut).balanceOf(user) - received;
        // expect 0.005 TokensTaiko.WETH
        assertApproxEqAbs(5022385816918292, received, 1);
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
        tks[0] = TokensTaiko.TAIKO;
        tks[1] = TokensTaiko.USDC;
        tks[2] = TokensTaiko.WETH;
        fees = new uint16[](2);
        fees[0] = DEX_FEE_LOW_HIGH;
        fees[1] = DEX_FEE_LOW_HIGH;
        pids = new uint8[](2);
        pids[0] = DexMappingsTaiko.UNI_V3;
        pids[1] = DexMappingsTaiko.KODO_VOLAT;
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
        tks[0] = TokensTaiko.WETH;
        tks[1] = TokensTaiko.USDC;
        tks[2] = TokensTaiko.TAIKO;
        fees = new uint16[](2);
        fees[0] = DEX_FEE_LOW_HIGH;
        fees[1] = DEX_FEE_LOW_HIGH;
        pids = new uint8[](2);
        pids[0] = DexMappingsTaiko.KODO_VOLAT;
        pids[1] = DexMappingsTaiko.UNI_V3;
    }

    function test_taiko_composer_multi_route_exact_in_native() external {
        address user = testUser;
        uint256 amount = 0.1e18;
        uint256 amountMin = 50.10e18;

        address assetIn = TokensTaiko.WETH;
        address assetOut = TokensTaiko.TAIKO;
        vm.deal(user, amount);

        bytes memory dataUni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.UNI_V3,
            DEX_FEE_LOW_HIGH //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getNativeToToken();
            dataFusion = getCompactPath(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, true, dataUni.length),
            dataUni,
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

    function test_taiko_composer_multi_route_exact_out_native_out() external {
        address user = testUser;
        uint256 amount = 0.01e18;
        uint256 amountMax = 2000.0e18;

        address assetIn = TokensTaiko.TAIKO;
        address assetOut = TokensTaiko.WETH;
        deal(assetIn, user, amountMax);

        bytes memory dataUni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.UNI_V3,
            DEX_FEE_LOW_HIGH //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getNativeToToken();
            dataFusion = getCompactPath(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            brokerProxyAddress,
            encodeSwapAmountParams(amount / 2, amountMax / 2, false, dataUni.length),
            dataUni,
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
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 19348096685317699468, 0);
    }

    function test_taiko_composer_multi_route_exact_out_native_in() external {
        address user = testUser;
        uint256 amount = 1000.0e18;
        uint256 amountMax = 1.0e18;

        address assetIn = TokensTaiko.WETH;
        address assetOut = TokensTaiko.TAIKO;
        vm.deal(user, amountMax);

        bytes memory dataUni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.UNI_V3,
            DEX_FEE_LOW_HIGH //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getTokenToNative();
            dataFusion = getCompactPath(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount / 2, amountMax / 2, true, dataUni.length),
            dataUni,
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
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 536614779499599354, 0);
    }

    function test_taiko_composer_multi_route_exact_in_native_out() external {
        address user = testUser;
        uint256 amount = 200.0e18;
        uint256 amountMin = 0.1e18;

        address assetIn = TokensTaiko.TAIKO;
        address assetOut = TokensTaiko.WETH;
        deal(assetIn, user, amount);

        bytes memory dataUni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.UNI_V3,
            DEX_FEE_LOW_HIGH //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getTokenToNative();
            dataFusion = getCompactPath(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            brokerProxyAddress,
            encodeSwapAmountParams(amount / 2, 0, false, dataUni.length),
            dataUni,
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

        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, 102863875609968494, 1);
        assertApproxEqAbs(balanceInBefore - balanceInAfter, amount, 0);
    }

    function test_taiko_composer_multi_route_exact_in_self() external {
        address user = testUser;
        uint256 amount = 20.0e6;
        uint256 amountMin = 19.0e6;

        address assetIn = TokensTaiko.USDC;
        address assetOut = TokensTaiko.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataUni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.UNI_V3,
            DEX_FEE_STABLES //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.UNI_V3,
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
            encodeSwapAmountParams(amount / 2, amountMin / 2, true, dataUni.length),
            dataUni,
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin / 2, true, dataFusion.length),
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

    function test_taiko_composer_multi_route_exact_out_x() external {
        address user = testUser;
        uint256 amount = 0.0010e18;
        uint256 maxIn = 40.0e6;

        address assetIn = TokensTaiko.USDC;
        address assetOut = TokensTaiko.WETH;
        deal(assetIn, user, 1e23);

        bytes memory dataUni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.DTX,
            DEX_FEE_LOW_HIGH //
        );
        bytes memory dataFusion = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            DexMappingsTaiko.UNI_V3,
            DEX_FEE_LOW_HIGH //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount / 2, maxIn, false, dataUni.length),
            dataUni,
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount / 2, maxIn, false, dataFusion.length),
            dataFusion //
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        uint balanceOutBefore = IERC20All(assetOut).balanceOf(user);
        uint balanceInBefore = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        uint balanceOutAfter = IERC20All(assetOut).balanceOf(user);
        uint balanceInAfter = IERC20All(assetIn).balanceOf(user);

        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, amount, 1);
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 2733647, 1);
    }

    function getCompactPath(address[] memory tokens, uint8[] memory pids, uint16[] memory fees) internal view returns (bytes memory data) {
        uint8[] memory actions = new uint8[](pids.length);
        data = abi.encodePacked(tokens[0]);
        for (uint i = 1; i < tokens.length; i++) {
            uint8 pId = pids[i - 1];
            if (pId < 50) {
                address pool = testQuoter.v3TypePool(tokens[i - 1], tokens[i], fees[i - 1], pId);
                data = abi.encodePacked(data, actions[i - 1], pId, pool, fees[i - 1], tokens[i]);
            } else {
                address pool = testQuoter.v2TypePairAddress(tokens[i - 1], tokens[i], pId);
                data = abi.encodePacked(
                    data,
                    actions[i - 1],
                    pId,
                    pool,
                    getV2PairFeeDenom(pId), //
                    tokens[i]
                );
            }
        }
        return abi.encodePacked(data, uint8(99));
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, poolId, pool, fee, tokenOut, uint8(99));
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
