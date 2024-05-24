// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract SwapGen2Test is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_mantle_gen_2_open_exact_in() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0));
        address assetFrom = USDC;
        address assetTo = USDT;
        address debtToken = debtTokens[assetFrom][lenderId];
        address collateralToken = collateralTokens[assetTo][lenderId];

        uint256 amountToSwap = 2000.0e6;
        uint256 amountToDeposit = 2000.0e6;
        deal(assetTo, user, amountToDeposit);

        bytes memory swapPath = getOpenExactInSingleGen2(assetFrom, assetTo, lenderId);
        uint256 minimumOut = 10.0e6;

        uint256 balanceCollateral = IERC20All(collateralToken).balanceOf(user);
        uint256 balanceDebt = IERC20All(debtToken).balanceOf(user);
        {
            bytes[] memory calls = new bytes[](2);
            calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetTo, amountToDeposit);
            calls[1] = abi.encodeWithSelector(ILending.deposit.selector, assetTo, user, lenderId);

            vm.prank(user);
            IERC20All(assetTo).approve(brokerProxyAddress, amountToDeposit);

            vm.prank(user);
            brokerProxy.multicall(calls);
        }

        vm.prank(user);
        IERC20All(debtToken).approveDelegation(address(brokerProxy), amountToSwap);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).flashSwapExactIn(amountToSwap, minimumOut, swapPath);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);

        balanceDebt = IERC20All(debtToken).balanceOf(user) - balanceDebt;
        balanceCollateral = IERC20All(collateralToken).balanceOf(user) - balanceCollateral;
        assertApproxEqAbs(balanceCollateral, 3999669280, 0);
        assertApproxEqAbs(amountToSwap, balanceDebt, 1e6);
    }

    function test_mantle_gen_2_open_exact_in_multi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0));

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensV3(lenderId);

        address debtToken = debtTokens[assetFrom][lenderId];
        address collateralToken = collateralTokens[assetTo][lenderId];

        uint256 amountToSwap = 1.0e6;
        uint256 amountToDeposit = 1.0e6;

        deal(assetTo, user, amountToDeposit);

        uint256 minimumOut = 0.90e6;

        uint256 balanceCollateral = IERC20All(collateralToken).balanceOf(user);
        uint256 balanceDebt = IERC20All(debtToken).balanceOf(user);
        {
            bytes[] memory calls = new bytes[](2);
            calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetTo, amountToDeposit);
            calls[1] = abi.encodeWithSelector(ILending.deposit.selector, assetTo, user, lenderId);

            vm.prank(user);
            IERC20All(assetTo).approve(brokerProxyAddress, amountToDeposit);

            vm.prank(user);
            brokerProxy.multicall(calls);
        }

        vm.prank(user);
        IERC20All(debtToken).approveDelegation(address(brokerProxy), amountToSwap);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).flashSwapExactIn(amountToSwap, minimumOut, swapPath);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);

        balanceDebt = IERC20All(debtToken).balanceOf(user) - balanceDebt;
        balanceCollateral = IERC20All(collateralToken).balanceOf(user) - balanceCollateral;
        assertApproxEqAbs(balanceCollateral, 1967753, 0);
        assertApproxEqAbs(amountToSwap, balanceDebt, 1e6);
    }

    function test_mantle_gen_2_open_exact_in_multi_mixed() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = DEFAULT_LENDER;
        vm.assume(user != address(0));

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensMixed(lenderId);

        address debtToken = debtTokens[assetFrom][lenderId];
        address collateralToken = collateralTokens[assetTo][lenderId];

        uint256 amountToSwap = 100.0e6;
        uint256 amountToDeposit = 100.0e6;

        deal(assetTo, user, amountToDeposit);

        uint256 minimumOut = 0.90e6;

        uint256 balanceCollateral = IERC20All(collateralToken).balanceOf(user);
        uint256 balanceDebt = IERC20All(debtToken).balanceOf(user);
        {
            bytes[] memory calls = new bytes[](2);
            calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetTo, amountToDeposit);
            calls[1] = abi.encodeWithSelector(ILending.deposit.selector, assetTo, user, lenderId);

            vm.prank(user);
            IERC20All(assetTo).approve(brokerProxyAddress, amountToDeposit);

            vm.prank(user);
            brokerProxy.multicall(calls);
        }

        vm.prank(user);
        IERC20All(debtToken).approveDelegation(address(brokerProxy), amountToSwap);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).flashSwapExactIn(amountToSwap, minimumOut, swapPath);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);

        balanceDebt = IERC20All(debtToken).balanceOf(user) - balanceDebt;
        balanceCollateral = IERC20All(collateralToken).balanceOf(user) - balanceCollateral;
        assertApproxEqAbs(balanceCollateral, 199483421, 0);
        assertApproxEqAbs(amountToSwap, balanceDebt, 1e6);
    }


    // function test_mantle_gen_2_spot_exact_in_multi() external /** address user, uint8 lenderId */ {
    //     address user = testUser;
    //     vm.assume(user != address(0));

    //     uint256 amountToSwap = 2.0e6;

    //     (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensV3();

    //     deal(assetFrom, user, 1e20);

    //     uint256 minimumOut = 1.0e6;

    //     vm.prank(user);
    //     IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

    //     uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
    //     uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

    //     vm.prank(user);
    //     uint256 gas = gasleft();
    //     IFlashAggregator(address(brokerProxy)).swapExactInSpot(amountToSwap, minimumOut, swapPath);
    //     gas = gas - gasleft();

    //     console.log("gas", gas, 144771);

    //     balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
    //     balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
    //     assertApproxEqAbs(balanceIn, amountToSwap, 0);
    //     // loses 0.2 USDT on the trade (due to low liquidity)
    //     assertApproxEqAbs(1806454, balanceOut, 1);
    // }

    // function test_mantle_gen_2_spot_exact_in_multi_mixed() external /** address user, uint8 lenderId */ {
    //     address user = testUser;
    //     vm.assume(user != address(0));

    //     uint256 amountToSwap = 2.0e6;

    //     (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensMixed();

    //     deal(assetFrom, user, 1e20);

    //     uint256 minimumOut = 1.0e6;

    //     vm.prank(user);
    //     IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

    //     uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
    //     uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

    //     vm.prank(user);
    //     uint256 gas = gasleft();
    //     IFlashAggregator(address(brokerProxy)).swapExactInSpot(amountToSwap, minimumOut, swapPath);
    //     gas = gas - gasleft();

    //     console.log("gas", gas, 144771);

    //     balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
    //     balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
    //     assertApproxEqAbs(balanceIn, amountToSwap, 0);
    //     // loses 0.2 USDT on the trade (due to low liquidity)
    //     assertApproxEqAbs(1990518, balanceOut, 1);
    // }

    // function test_mantle_gen_2_spot_exact_in_V2() external /** address user, uint8 lenderId */ {
    //     address user = testUser;
    //     vm.assume(user != address(0));
    //     address assetFrom = USDC;

    //     address assetTo = USDT;
    //     deal(assetFrom, user, 1e20);

    //     uint256 amountToSwap = 200.0e6;

    //     bytes memory swapPath = getOpenExactInSingleGen2V2(assetFrom, assetTo);
    //     uint256 minimumOut = 10.0e6;

    //     vm.prank(user);
    //     IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

    //     uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
    //     uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

    //     vm.prank(user);
    //     uint256 gas = gasleft();
    //     IFlashAggregator(address(brokerProxy)).swapExactInSpot(amountToSwap, minimumOut, swapPath);
    //     gas = gas - gasleft();
    //     console.log("gas", gas, 144771);
    //     balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
    //     balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
    //     assertApproxEqAbs(balanceIn, amountToSwap, 0);
    //     assertApproxEqAbs(198751420, balanceOut, 1);
    // }

    function getOpenExactInSingleGen2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        uint8 poolId = AGNI;
        return abi.encodePacked(tokenIn, uint8(6), poolId, fee, tokenOut, lenderId, uint8(2));
    }

    function getPathDataV3() internal view returns (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) {
        uint256 length = 4;
        uint256 lengthDecreased = length - 1;
        tokens = new address[](length);
        actions = new uint8[](lengthDecreased);
        pIds = new uint8[](lengthDecreased);
        fees = new uint16[](lengthDecreased);
        tokens[0] = USDC;
        tokens[1] = WMNT;
        tokens[2] = WETH;
        tokens[3] = USDT;
        pIds[0] = FUSION_X;
        pIds[1] = AGNI;
        pIds[2] = AGNI;
        actions[0] = 6;
        actions[1] = 0;
        actions[2] = 0;
        fees[0] = 2500;
        fees[1] = 500;
        fees[2] = 500;
    }

    function getPathDataMixed() internal view returns (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) {
        uint256 length = 4;
        uint256 lengthDecreased = length - 1;
        tokens = new address[](length);
        actions = new uint8[](lengthDecreased);
        pIds = new uint8[](lengthDecreased);
        fees = new uint16[](lengthDecreased);
        tokens[0] = USDC;
        tokens[1] = WMNT;
        tokens[2] = WETH;
        tokens[3] = USDT;
        pIds[0] = MERCHANT_MOE;
        pIds[1] = AGNI;
        pIds[2] = AGNI;
        actions[0] = 6;
        actions[1] = 0;
        actions[2] = 0;
        fees[0] = 2500;
        fees[1] = 500;
        fees[2] = 500;
    }

    function getOpenExactInSingleGen2Mixed(
        address[] memory tokens,
        uint8[] memory actions,
        uint8[] memory pIds,
        uint16[] memory fees,
        uint8 lenderId,
        uint8 endId
    ) internal pure returns (bytes memory path) {
        path = abi.encodePacked(tokens[0]);
        for (uint i = 1; i < tokens.length; i++) {
            uint8 pId = pIds[i - 1];
            if (pId < 50) path = abi.encodePacked(path, actions[i - 1], pIds[i - 1], fees[i - 1], tokens[i]);
            else path = abi.encodePacked(path, actions[i - 1], pIds[i - 1], tokens[i]);
        }
        path = abi.encodePacked(path, lenderId, endId);
    }

    function getPathAndTokensMixed(uint8 lenderId) internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataMixed();
        return (
            tokens[0],
            tokens[tokens.length - 1],
            getOpenExactInSingleGen2Mixed(tokens, actions, pIds, fees, lenderId, uint8(2)) //
        );
    }

    function getPathAndTokensV3(uint8 lenderId) internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataV3();
        return (
            tokens[0],
            tokens[tokens.length - 1],
            getOpenExactInSingleGen2Mixed(tokens, actions, pIds, fees, lenderId, uint8(2)) //
        );
    }

    function getOpenExactInSingleGen2V2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        return abi.encodePacked(tokenIn, uint8(10), poolId, tokenOut);
    }
}
