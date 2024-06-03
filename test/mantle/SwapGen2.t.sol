// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract SwapGen2Test is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable
    address internal LEND = 0x25356aeca4210eF7553140edb9b8026089E49396;

    function test_mantle_gen_2_spot_exact_in() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = USDC;

        address assetTo = USDT;
        deal(assetFrom, user, 1e20);

        uint256 amountToSwap = 2000.0e6;

        bytes memory swapPath = getSpotExactInSingleGen2(assetFrom, assetTo);
        uint256 minimumOut = 10.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).swapExactInSpot(amountToSwap, minimumOut, user, swapPath);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(amountToSwap, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_in_v2_fusion_pure() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = WMNT;

        address assetTo = LEND;
        deal(assetFrom, user, 1e20);

        uint256 amountToSwap = 20.0e6;

        bytes memory swapPath = getSpotExactInSingleGen2FusionX(assetFrom, assetTo);
        uint256 minimumOut = 10.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(address(aggregator), amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        aggregator.swapExactInSpot(amountToSwap, minimumOut, user, swapPath);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(178522773, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_out() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = USDC;

        address assetTo = USDT;
        deal(assetFrom, user, 1e20);

        uint256 amountToReceive = 2000.0e6;

        bytes memory swapPath = getSpotExactOutSingleGen2(assetFrom, assetTo);
        uint256 maximumIn = 2300.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).swapExactOutSpot(amountToReceive, maximumIn, user, swapPath);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, 2000330778, 0);
        assertApproxEqAbs(amountToReceive, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_out_multi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amountToReceive = 1.0e6;

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensV3ExactOut();

        deal(assetFrom, user, 1e20);

        uint256 maximumIn = 6.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).swapExactOutSpot(amountToReceive, maximumIn, user, swapPath);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, 1090371, 0);
        assertApproxEqAbs(amountToReceive, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_out_multi_mixed() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amountToReceive = 1.0e6;

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensMixedExectOut();

        deal(assetFrom, user, 1e20);

        uint256 maximumIn = 6.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).swapExactOutSpot(amountToReceive, maximumIn, user, swapPath);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, 1003277, 0);
        assertApproxEqAbs(amountToReceive, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_in_multi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amountToSwap = 2.0e6;

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensV3();

        deal(assetFrom, user, 1e20);

        uint256 minimumOut = 1.0e6;

        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).swapExactInSpot(amountToSwap, minimumOut, user, swapPath);
        gas = gas - gasleft();

        console.log("gas", gas, 144771);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        // loses 0.2 USDT on the trade (due to low liquidity)
        assertApproxEqAbs(1993355, balanceOut, 1);
    }

    function test_mantle_gen_2_spot_exact_in_multi_mixed() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amountToSwap = 2.0e6;

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensMixed();

        deal(assetFrom, user, 1e20);

        uint256 minimumOut = 1.0e6;

        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).swapExactInSpot(amountToSwap, minimumOut, user, swapPath);
        gas = gas - gasleft();

        console.log("gas", gas, 144771);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        // loses 0.2 USDT on the trade (due to low liquidity)
        assertApproxEqAbs(1990518, balanceOut, 1);
    }

    function test_mantle_gen_2_spot_exact_in_V2() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = USDC;

        address assetTo = USDT;
        deal(assetFrom, user, 1e20);

        uint256 amountToSwap = 200.0e6;

        bytes memory swapPath = getSpotExactInSingleGen2V2(assetFrom, assetTo);
        uint256 minimumOut = 10.0e6;

        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(address(brokerProxy)).swapExactInSpot(amountToSwap, minimumOut, user, swapPath);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);
        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(198751420, balanceOut, 1);
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(10), poolId, pool, fee, tokenOut);
    }

    function getSpotExactInSingleGen2FusionX(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = FUSION_X_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, uint8(10), poolId, pool, tokenOut);
    }

    function getSpotExactOutSingleGen2(address tokenOut, address tokenIn) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(11), poolId, pool, fee, tokenOut);
    }

    function getPathDataV3()
        internal
        view
        returns (
            //
            address[] memory tokens,
            uint8[] memory actions,
            uint8[] memory pIds,
            uint16[] memory fees
        )
    {
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
        pIds[0] = CLEOPATRA_CL;
        pIds[1] = AGNI;
        pIds[2] = AGNI;
        actions[0] = 10;
        actions[1] = 0;
        actions[2] = 0;
        fees[0] = 250;
        fees[1] = 500;
        fees[2] = 500;
    }

    function getPathDataV3ExactOut()
        internal
        view
        returns (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees)
    {
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
        actions[0] = 1;
        actions[1] = 1;
        actions[2] = 11;
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
        actions[0] = 10;
        actions[1] = 0;
        actions[2] = 0;
        fees[0] = 2500;
        fees[1] = 500;
        fees[2] = 500;
    }

    function getPathDataMixedExactOut()
        internal
        view
        returns (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees)
    {
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
        actions[0] = 1;
        actions[1] = 1;
        actions[2] = 11;
        fees[0] = 2500;
        fees[1] = 500;
        fees[2] = 500;
    }

    function getSpotSingleGen2Mixed(
        address[] memory tokens,
        uint8[] memory actions,
        uint8[] memory pIds,
        uint16[] memory fees
    ) internal view returns (bytes memory path) {
        path = abi.encodePacked(tokens[0]);
        for (uint i = 1; i < tokens.length; i++) {
            uint8 pId = pIds[i - 1];
            if (pId < 50) {
                address pool = testQuoter._v3TypePool(tokens[i - 1], tokens[i], fees[i - 1], pId);
                path = abi.encodePacked(path, actions[i - 1], pId, pool, fees[i - 1], tokens[i]);
            } else {
                address pool = testQuoter._v2TypePairAddress(tokens[i - 1], tokens[i], pId);
                path = abi.encodePacked(path, actions[i - 1], pId, pool, tokens[i]);
            }
        }
    }

    function getPathAndTokensMixed() internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataMixed();
        return (
            tokens[0],
            tokens[tokens.length - 1],
            getSpotSingleGen2Mixed(tokens, actions, pIds, fees) //
        );
    }

    function getPathAndTokensV3() internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataV3();
        return (
            tokens[0],
            tokens[tokens.length - 1],
            getSpotSingleGen2Mixed(tokens, actions, pIds, fees) //
        );
    }

    function getPathAndTokensV3ExactOut() internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataV3ExactOut();
        return (
            tokens[tokens.length - 1],
            tokens[0],
            getSpotSingleGen2Mixed(tokens, actions, pIds, fees) //
        );
    }

    function getPathAndTokensMixedExectOut() internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataMixedExactOut();
        return (
            tokens[tokens.length - 1],
            tokens[0],
            getSpotSingleGen2Mixed(tokens, actions, pIds, fees) //
        );
    }

    function getSpotExactInSingleGen2V2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, uint8(10), poolId, pool, tokenOut);
    }
}
