// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract SwapGen2Test is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_mantle_gen_2_spot_exact_in() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = USDC;

        address assetTo = USDT;
        deal(assetFrom, user, 1e20);

        uint256 amountToSwap = 2000.0e6;

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetFrom, amountToSwap);

        bytes memory swapPath = getOpenExactInSingleGen2(assetFrom, assetTo);
        uint256 minimumOut = 10.0e6;
        calls[1] = abi.encodeWithSelector(IFlashAggregator.swapExactInSpot.selector, amountToSwap, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        console.log("PRANK");
        vm.prank(user);
        uint256 gas = gasleft();
        brokerProxy.multicall(calls);
        gas = gas - gasleft();
        console.log("gas", gas, 144771);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        // deposit 10, recieve 32.1... makes 42.1...
        // assertApproxEqAbs(39122533, balance, 1);
        // // deviations through rouding expected, accuracy for 10 decimals
        // assertApproxEqAbs(borrowBalance, amountToDeposit + amountToLeverage, 1.0e8);
    }

    function getOpenExactInSingleGen2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        uint8 poolId = AGNI;
        // address pair = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, fee, tokenOut, uint8(99));
    }
}
