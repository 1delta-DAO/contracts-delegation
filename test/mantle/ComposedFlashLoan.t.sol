// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginOpenTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_mantle_composed_fl(uint8 lenderId) external /** address user, uint8 lenderId */ {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        {
            address asset = USDC;

            address borrowAsset = WMNT;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 10.0e6;

            uint256 amountToBorrow = 20.0e18;
            uint256 minimumOut = 10.0e6;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToBorrow,
                minimumOut, //
                lenderId
            );
        }
        uint256 borrowBalance = IERC20All(params.debtToken).balanceOf(user);
        uint256 balance = IERC20All(params.collateralToken).balanceOf(user);

        bytes memory data = encodeAaveV2FlashLoan(
            params.borrowAsset,
            params.swapAmount,
            lenderId,
            abi.encodePacked(address(this))
        );
        console.log("begin");
        vm.prank(user);
        // IFlashAggregator(brokerProxyAddress)
        aggregator.deltaCompose(data);

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39122533, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, params.amountToDeposit + params.swapAmount, 1.0e8);
    }
}
