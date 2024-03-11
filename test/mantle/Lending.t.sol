// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract LendingTest is DeltaSetup {
    address testUser = 0xcccccda06B44bcc94618620297Dc252EcfB56d85;

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 60500956, urlOrAlias: "https://rpc.ankr.com/mantle"});

        deployDelta();
        initializeDelta();
    }

    function test_lending_mantle_deposit() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = 1;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        deal(asset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        _deposit(asset, user, amountToDeposit, lenderId);
    }

    function test_lending_mantle_borrow() external /** address user, uint8 lenderId */ {
        address user = testUser;
        uint8 lenderId = 1;
        vm.assume(user != address(0) && lenderId < 2);
        address depositAsset = USDT;

        address asset = USDC;
        address debtAsset = AURELIUS_V_USDC;

        deal(depositAsset, user, 1e20);

        uint256 amountToDeposit = 10.0e6;

        _deposit(depositAsset, user, amountToDeposit, lenderId);

        uint256 balanceBefore = IERC20All(asset).balanceOf(user);
        uint256 amountToBorrow = 5.0e6;
        _borrow(asset, debtAsset, user, amountToBorrow, lenderId);

        uint256 balance = IERC20All(asset).balanceOf(user);
        assertApproxEqAbs(balance - balanceBefore, amountToBorrow, 0);
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

    function _borrow(address asset, address debtAsset, address user, uint256 amount, uint8 lenderId) internal {
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amount);
        // create calls for open
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.borrow.selector, asset, amount, 2, lenderId);
        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, asset);

        vm.prank(user);
        brokerProxy.multicall(calls);
    }
}
