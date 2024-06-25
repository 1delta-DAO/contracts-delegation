// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {DeflatingERC20} from "../mocks/DeflatingERC20.sol";
import "./DeltaSetup.f.sol";

interface IV2Router {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

contract SwapGen2Test is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable
    address internal constant FUSION_ROUTER = 0xDd0840118bF9CCCc6d67b2944ddDfbdb995955FD;
    address internal constant creator = 0x432a74fD707A04aD2d45E4607d555D2eC73b202d;

    function prepFOTToken(address otherToken) internal returns (address token) {
        vm.prank(creator);
        DeflatingERC20 t = new DeflatingERC20(1_000_000.0e18);

        vm.prank(creator);
        t.approve(FUSION_ROUTER, type(uint).max);
        vm.prank(creator);
        IERC20All(otherToken).approve(FUSION_ROUTER, type(uint).max);

        deal(otherToken, creator, 2e30);
        token = address(t);
        vm.prank(creator);
        IV2Router(FUSION_ROUTER).addLiquidity(
            token,
            otherToken,
            100_000.0e18, // add 1:1 liquidity
            100_000.0e18,
            0,
            0,
            creator,
            type(uint).max //
        );
        console.log("supplied fot token", token);
    }

    function test_mantle_gen_2_buy_FOT() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = USDT;
        address mid = WMNT;
        address assetTo = prepFOTToken(mid);
        deal(assetFrom, user, 1e20);

        uint256 amountToSwap = 2000.0e6;

        bytes memory swapPath = getSpotExactInBuyFOT(assetFrom, mid, assetTo);
        uint256 minimumOut = 10.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, // 
            minimumOut,
            false,
            swapPath
        );

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(373776188540138142370, balanceOut, 1e6);
    }

    function test_mantle_gen_2_sell_FOT() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));
        address mid = WMNT;
        address assetFrom = prepFOTToken(mid);
        address assetTo = USDT;
        uint256 amountToSwap = 200.0e18;
        deal(assetFrom, user, amountToSwap * 2);

        bytes memory swapPath = getSpotExactInSellFOT(assetFrom, mid, assetTo);
        uint256 minimumOut = 10.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParamsFOT(
                amountToSwap,
                minimumOut,
                false,
                true,
                swapPath.length
            ),
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        // IFlashAggregator(brokerProxyAddress).swapExactInSpot(amountToSwap, minimumOut, user, swapPath);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(217616511, balanceOut, 1e6);
    }

    function getSpotExactInBuyFOT(address tokenIn, address mid, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = FUSION_X_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, mid, poolId);
        data = abi.encodePacked(tokenIn, uint8(0), poolId, pool, mid);
        pool = testQuoter._v2TypePairAddress(tokenOut, mid, poolId);
        poolId = FUSION_X_V2;
        return abi.encodePacked(data, uint8(0), poolId, pool, tokenOut);
    }

        function getSpotExactInSellFOT(address tokenIn, address mid, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = FUSION_X_V2;
        address pool = testQuoter._v2TypePairAddress(tokenIn, mid, poolId);
        data = abi.encodePacked(tokenIn, uint8(0), poolId, pool, mid);
        poolId = FUSION_X_V2;
        pool = testQuoter._v2TypePairAddress(tokenOut, mid, poolId);
        return abi.encodePacked(data, uint8(0), poolId, pool, tokenOut);
    }
}
