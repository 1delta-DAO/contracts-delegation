// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginOpenTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_spot_exact_in_izi() external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0));

        address asset = USDT;
        address assetOut = WMNT;

        deal(asset, user, 1e20);

        uint256 amountToSwap = 20.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToSwap);

        bytes memory swapPath = getSpotExactInSingle_izi(asset, assetOut);
        uint256 minimumOut = 13.0e18;
        calls[1] = abi.encodeWithSelector(IFlashAggregator.swapExactInSpot.selector, amountToSwap, minimumOut, swapPath);
        calls[2] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToSwap);

        uint256 inBalance = IERC20All(asset).balanceOf(user);
        uint256 balance = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(assetOut).balanceOf(user) - balance;
        inBalance = inBalance - IERC20All(asset).balanceOf(user);

        // deposit 10, recieve 13
        assertApproxEqAbs(amountToSwap, inBalance, 1);
        assertApproxEqAbs(13318419467531051937, balance, 1);
    }
}
