// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginOpenTest is DeltaSetup {
    function test_margin_mantle_spot_exact_in_izi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = TokensMantle.USDT;
        address assetOut = TokensMantle.WMNT;

        deal(asset, user, 1e20);

        uint256 amountToSwap = 20.0e6;

        bytes memory swapPath = getSpotExactInSingle_izi(asset, assetOut);
        uint256 minimumOut = 13.0e18;

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToSwap);

        uint256 inBalance = IERC20All(asset).balanceOf(user);
        uint256 balance = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - IERC20All(asset).balanceOf(user);

        // deposit 10, recieve 13
        assertApproxEqAbs(amountToSwap, inBalance, 1);
        assertApproxEqAbs(13318419467531051937, balance, 1);
    }

    function test_margin_mantle_spot_exact_out_izi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = TokensMantle.USDT;
        address assetOut = TokensMantle.WMNT;

        deal(asset, user, 1e30);

        uint256 amountToSwap = 18.0e18;

        bytes memory swapPath = getSpotExactOutSingle_izi(asset, assetOut);
        uint256 maximumIn = 30.0e6;

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, maximumIn);

        uint256 inBalance = IERC20All(asset).balanceOf(user);
        uint256 balance = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToSwap, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - IERC20All(asset).balanceOf(user);

        // deposit 10, recieve 13
        assertApproxEqAbs(27030539, inBalance, 1);
        // izi can be unprecise
        assertApproxEqAbs(amountToSwap, balance, 1e7);
    }

    function test_margin_mantle_spot_exact_out_native_in() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = TokensMantle.WMNT;
        address assetOut = TokensMantle.USDT;

        uint256 amountToSwap = 30.0e6;
        uint256 maximumIn = 30.0e18;

        vm.deal(user, maximumIn);

        bytes memory calls;

        calls = getSpotExactOutSingle_izi(asset, assetOut);

        calls = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToSwap,
            maximumIn,
            true, // internal
            calls
        );
        bytes memory wr = wrap(maximumIn);
        bytes memory ur = unwrap(user, 0, SweepType.VALIDATE);

        calls = abi.encodePacked(wr, calls, ur);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, maximumIn);

        uint256 inBalance = user.balance;
        uint256 balance = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose{value: maximumIn}(calls);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - user.balance;

        // deposit 10, recieve 13
        assertApproxEqAbs(20100460398190718408, inBalance, 1);
        // izi can be unprecise
        assertApproxEqAbs(amountToSwap, balance, 1e7);
    }

    function test_margin_mantle_spot_exact_out_native_in_multi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = TokensMantle.WMNT;
        address assetOut = TokensMantle.USDC;

        uint256 amountToSwap = 30.0e6;

        uint256 maximumIn = 30.0e18;
        vm.deal(user, maximumIn);

        bytes memory calls;

        calls = getSpotExactOutMultiNativeIn(asset, assetOut);

        calls = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToSwap,
            maximumIn,
            true, // internal
            calls
        );
        bytes memory wr = wrap(maximumIn);
        bytes memory ur = unwrap(user, 0, SweepType.VALIDATE);

        calls = abi.encodePacked(wr, calls, ur);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, maximumIn);

        uint256 inBalance = user.balance;
        uint256 balance = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose{value: maximumIn}(calls);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - user.balance;

        // deposit 10, recieve 13
        assertApproxEqAbs(20101429314690533657, inBalance, 1);
        // izi can be unprecise
        assertApproxEqAbs(amountToSwap, balance, 1e7);
    }

    function test_margin_mantle_spot_exact_in_izi_reverted() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = TokensMantle.WMNT;
        address assetOut = TokensMantle.USDT;

        deal(asset, user, 1e20);

        uint256 amountToSwap = 20.0e18;

        bytes memory swapPath = getSpotExactInSingle_izi(asset, assetOut);
        uint256 minimumOut = 13.0e6;

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToSwap);

        uint256 inBalance = IERC20All(asset).balanceOf(user);
        uint256 balance = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - IERC20All(asset).balanceOf(user);

        // deposit 10, recieve 13
        assertApproxEqAbs(amountToSwap, inBalance, 100_000); // 100k = 1e-13
        assertApproxEqAbs(29850074, balance, 1);
    }

    function test_margin_mantle_spot_exact_out_izi_reverted() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = TokensMantle.WMNT;
        address assetOut = TokensMantle.USDT;

        deal(asset, user, 1e30);

        uint256 amountToSwap = 18.0e6;

        bytes memory swapPath = getSpotExactOutSingle_izi(asset, assetOut);
        uint256 maximumIn = 30.0e18;

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, maximumIn);

        uint256 inBalance = IERC20All(asset).balanceOf(user);
        uint256 balance = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToSwap, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - IERC20All(asset).balanceOf(user);

        // deposit 10, recieve 13
        assertApproxEqAbs(12059995241668815957, inBalance, 1);
        // izi can be unprecise
        assertApproxEqAbs(amountToSwap, balance, 1e7);
    }

    function getSpotExactOutMultiNativeIn(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        uint8 poolId = DexMappingsMantle.FUSION_X;
        address pool = testQuoter._v3TypePool(tokenOut, TokensMantle.USDT, fee, poolId);
        data = abi.encodePacked(tokenOut, uint8(0), poolId, pool, fee, TokensMantle.USDT);
        fee = DEX_FEE_LOW_HIGH;
        poolId = DexMappingsMantle.IZUMI;
        pool = testQuoter._getiZiPool(tokenIn, TokensMantle.USDT, fee);
        return abi.encodePacked(data, uint8(0), poolId, pool, fee, tokenIn, uint8(0), uint8(99));
    }
}
