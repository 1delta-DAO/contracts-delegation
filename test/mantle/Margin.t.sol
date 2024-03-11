// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import {DexConfigMantle} from "./DexConfig.f.sol";

contract MarginTest is DeltaSetup, DexConfigMantle {
    address testUser = 0xcccccda06B44bcc94618620297Dc252EcfB56d85;

    uint256 DEFAULT_IR_MODE = 2; // variable

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 60500956, urlOrAlias: "https://rpc.ankr.com/mantle"});

        deployDelta();
        initializeDelta();
    }

    function test_margin_mantle_open() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = 1;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[USDC][lenderId];

        address borrowAsset = WMNT;
        address debtAsset = debtTokens[WMNT][lenderId];
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToLeverage = 30.0e18;
        bytes memory swapPath = getOpenExactInSingle(borrowAsset, asset, lenderId);
        uint256 minimumOut = 30.0e6;
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

        assert(amountToLeverage / 1e12 + amountToDeposit >= balance * 90 / 100);
        assertApproxEqAbs(borrowBalance, amountToDeposit + amountToLeverage, 1.0e8);
    }

    function getOpenExactInSingle(address tokenIn, address tokenOut, uint8 lenderId) private view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(lenderId, tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function _deposit(address asset, address user, uint256 amount, uint8 lenderId) internal {
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amount);
        // create calls for open
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amount);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        vm.prank(user);
        brokerProxy.multicall(calls);
    }

    function _withdraw(address asset, address collateralAsset, address user, uint256 amount, uint8 lenderId) internal {
        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amount);
        // create calls for open
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, collateralAsset, amount);
        calls[1] = abi.encodeWithSelector(ILending.withdraw.selector, asset, user, lenderId);
        calls[2] = abi.encodeWithSelector(ILending.sweep.selector, asset);

        vm.prank(user);
        brokerProxy.multicall(calls);
    }

    function _borrow(address asset, address debtAsset, address user, uint256 amount, uint8 lenderId) internal {
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amount);
        // create calls for open
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.borrow.selector, asset, amount, DEFAULT_IR_MODE, lenderId);
        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, asset);

        vm.prank(user);
        brokerProxy.multicall(calls);
    }

    function _repay(address asset, address user, uint256 amount, uint8 lenderId) internal {
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amount);
        // create calls for open
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amount);
        calls[1] = abi.encodeWithSelector(ILending.repay.selector, asset, user, DEFAULT_IR_MODE, lenderId);

        vm.prank(user);
        brokerProxy.multicall(calls);
    }
}
