// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
// mock
import {MockRouter} from "../../contracts/mocks/MockRouter.sol";

contract LendleFlashModuleTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable
    MockRouter router;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63530165, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        router = new MockRouter(1.0e18, 12);

        deployDelta();
        initializeDelta();

        management.approveAddress(getAssets(), address(router));
        management.setValidTarget(address(router), true);
    }

    function test_mantle_lendle_flash_open() external {
        uint8 lenderId = 0;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = USDT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, 1e20);
        deal(asset, address(router), 1e20);
        deal(borrowAsset, address(router), 1e20);

        uint256 amountToDeposit = 10.0e6;

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amountToDeposit);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user, lenderId);

        uint256 amountToLeverage = 20.0e6;

        uint256 premi = ILendingPool(LENDLE_POOL).FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToFlashRepay = (amountToLeverage * 10000) / (10000 - premi);
        IFlashLoanReceiver.DeltaParams memory deltaParams = IFlashLoanReceiver.DeltaParams({
            baseAsset: asset, // the asset paired with the flash loan
            target: address(router), // the swap target
            marginTradeType: 0,
            // 0 = Margin open
            // 1 = margin close
            // 2 = collateral / open
            // 3 = debt / close
            interestRateModeIn: uint8(DEFAULT_IR_MODE), // aave interest mode
            interestRateModeOut: 0, // aave interest mode
            withdrawMax: false
        });

        calls[2] = abi.encodeWithSelector(
            IFlashLoanReceiver.executeOnLendle.selector,
            borrowAsset,
            amountToLeverage,
            deltaParams,
            getOpenMock(borrowAsset, asset, amountToLeverage)
        );

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountToDeposit);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amountToFlashRepay);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 20... makes 30...
        assertApproxEqAbs(29999989, balance, 1);
        // deviations through rouding expected, accuracy for 0.00002
        assertApproxEqAbs(borrowBalance, amountToFlashRepay, 20);
    }

    function test_mantle_lendle_flash_close() external {
        uint8 lenderId = 0;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = USDT;

        deal(asset, address(router), 1e20);
        deal(borrowAsset, address(router), 1e20);

        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e6;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, 0);
        }

        bytes[] memory calls = new bytes[](1);

        uint256 amountIn = 15.0e6;

        uint256 premi = ILendingPool(LENDLE_POOL).FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToFlashWithdraw = (amountIn * 10000) / (10000 - premi);
        IFlashLoanReceiver.DeltaParams memory deltaParams = IFlashLoanReceiver.DeltaParams({
            baseAsset: borrowAsset, // the asset paired with the flash loan
            target: address(router), // the swap target
            marginTradeType: 1,
            // 0 = Margin open
            // 1 = margin close
            // 2 = collateral / open
            // 3 = debt / close
            interestRateModeIn: 0, // aave interest mode
            interestRateModeOut: uint8(DEFAULT_IR_MODE), // aave interest mode
            withdrawMax: false
        });

        calls[0] = abi.encodeWithSelector(
            IFlashLoanReceiver.executeOnLendle.selector,
            asset,
            amountToFlashWithdraw,
            deltaParams,
            getOpenMock(asset, borrowAsset, amountIn)
        );

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountToFlashWithdraw);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(amountToFlashWithdraw, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(14999988, borrowBalance, 1);
    }

    function getOpenMock(address tokenIn, address tokenOut, uint256 amountIn) internal pure returns (bytes memory data) {
        return abi.encodeWithSelector(MockRouter.swapExactIn.selector, tokenIn, tokenOut, amountIn);
    }
}
