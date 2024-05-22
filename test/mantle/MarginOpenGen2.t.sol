// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginOpenTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_margin_mantle_open_exact_in(uint8 lenderId) external /** address user, uint8 lenderId */ {
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToLeverage = 20.0e18;
        bytes memory swapPath = getOpenExactInSingleGen2(borrowAsset, asset, lenderId);
        uint256 minimumOut = 10.0e6;
        calls[2] = abi.encodeWithSelector(IFlashAggregator.flashSwapExactIn.selector, amountToLeverage, minimumOut, swapPath);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amountToLeverage);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39122533, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, amountToDeposit + amountToLeverage, 1.0e8);
    }


    function getOpenExactInSingleGen2(address tokenIn, address tokenOut, uint8 lenderId) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, lenderId, endId);
    }

}
