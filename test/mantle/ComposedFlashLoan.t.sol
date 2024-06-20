// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginOpenTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_mantle_composed_flash_loan(uint8 lenderId) external /** address user, uint8 lenderId */ {
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        vm.deal(user, 1.0e18);
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

        vm.prank(user);
        IERC20All(params.collateralAsset).approve(brokerProxyAddress, params.amountToDeposit);

        bytes memory initTransfer = transferIn(
            params.collateralAsset,
            brokerProxyAddress,
            params.amountToDeposit // init depo
        );

        bytes memory dataDeposit = deposit(
            params.collateralAsset,
            user,
            0, // all, incl init depo
            lenderId
        );
        bytes memory dataBorrow;
        {
            uint borrowAm = params.swapAmount + (params.swapAmount * ILendingPool(LENDLE_POOL).FLASHLOAN_PREMIUM_TOTAL()) / 10000;
            vm.prank(user);
            IERC20All(params.debtToken).approveDelegation(brokerProxyAddress, borrowAm);

            dataBorrow = borrow(
                params.borrowAsset,
                brokerProxyAddress,
                borrowAm,
                lenderId,
                uint8(DEFAULT_IR_MODE) //
            );
        }
        bytes memory swap = encodeSwap(
            Commands.SWAP_EXACT_IN,
            brokerProxyAddress,
            params.swapAmount,
            0,
            true,
            getOpenExactInInternal(
                params.borrowAsset,
                params.collateralAsset //
            )
        );
        bytes memory data = abi.encodePacked(
            initTransfer,
            encodeAaveV2FlashLoan(
                params.borrowAsset,
                params.swapAmount,
                lenderId,
                abi.encodePacked(swap, dataDeposit, dataBorrow) //
            )
        );

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas-flash-loan-open", gas);

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(39122533, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, 20018000000000000000, 1.0e8);
    }

    function getOpenExactInInternal(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut, uint8(0), uint8(0));
    }
}
