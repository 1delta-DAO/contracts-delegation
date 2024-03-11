// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginTest is DeltaSetup {
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

        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        uint256 balanceBefore = IERC20All(collateralAsset).balanceOf(user);
        _deposit(asset, user, amountToDeposit, lenderId);

        uint256 balance = IERC20All(collateralAsset).balanceOf(user);
        assertApproxEqAbs(balance - balanceBefore, amountToDeposit, 0);
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
