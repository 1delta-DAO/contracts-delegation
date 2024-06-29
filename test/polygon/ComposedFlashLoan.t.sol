// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ComposedFlashLoanTestPolygon is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    /**
     * Transfers in
     * flash loan
     *  swap
     *  depoist
     *  borrow
     *  payback
     */
    function test_polygon_composed_flash_loan_open(uint8 lenderId) external /** address user, uint8 lenderId */ {
        TestParamsOpen memory params;
        address user = testUser;

        vm.assume(user != address(0) && (lenderId < 2 || lenderId == 50));
        vm.deal(user, 1.0e18);
        {
            address asset = WMATIC;

            address borrowAsset = USDC;

            uint256 amountToDeposit = 200.0e18;
            deal(asset, user, amountToDeposit);

            uint256 amountToBorrow = 100.0e6; // need to borrow at least 100 for C3
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
        uint256 borrowBalance = getBorrowBalance(user, params.borrowAsset, lenderId);
        uint256 balance = getCollateralBalance(user, params.collateralAsset, lenderId);

        vm.prank(user);
        IERC20All(params.collateralAsset).approve(brokerProxyAddress, params.amountToDeposit);

        bytes memory initTransfer = transferIn(
            params.collateralAsset,
            brokerProxyAddress,
            params.amountToDeposit // init depo
        );

        bytes memory dataLending = deposit(
            params.collateralAsset,
            user,
            0, // all, incl init depo
            lenderId
        );

        uint8 flashSource = BALANCER_V2;
        {
            uint borrowAm = params.swapAmount +
                (params.swapAmount * (flashSource == BALANCER_V2 ? 0 : ILendingPool(AAVE_POOL).FLASHLOAN_PREMIUM_TOTAL())) / //
                10000;

            approveBorrowDelegation(user, params.borrowAsset, borrowAm, lenderId);

            dataLending = abi.encodePacked(
                dataLending,
                borrow(
                    params.borrowAsset,
                    BALANCER_VAULT,
                    borrowAm,
                    lenderId,
                    uint8(DEFAULT_IR_MODE) //
                )
            );
        }
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            brokerProxyAddress,
            params.swapAmount,
            0, // do not slippage check here
            true, // self
            getOpenExactInInternal(
                params.borrowAsset,
                params.collateralAsset //
            )
        );
        data = abi.encodePacked(data, dataLending);
        data = abi.encodePacked(
            initTransfer,
            encodeAaveV2FlashLoan(
                params.borrowAsset,
                params.swapAmount,
                flashSource,
                data //
            )
        );
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();

        console.log("gas-flash-loan-open", gas);

        balance = getCollateralBalance(user, params.collateralAsset, lenderId) - balance;
        borrowBalance = getBorrowBalance(user, params.borrowAsset, lenderId) - borrowBalance;

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(379869471726271100564, balance, 1);
        {
            uint borrowAm = params.swapAmount +
                (params.swapAmount * (flashSource == BALANCER_V2 ? 0 : ILendingPool(AAVE_POOL).FLASHLOAN_PREMIUM_TOTAL())) / //
                10000;
            // deviations through rouding expected, accuracy for 10 decimals
            assertApproxEqAbs(borrowBalance, borrowAm, 1);
        }
    }

    function test_polygon_ext_call() external {
        address someAddr = vm.addr(0x324);
        address someOtherAddr = vm.addr(0x324);

        management.setValidTarget(someAddr, someOtherAddr, true);

        bool val = management.getIsValidTarget(someAddr, someOtherAddr);
        console.log(val);
    }

    function test_polygon_composed_flash_loan_close() external {
        uint8 lenderId = 0;
        address user = testUser;
        vm.assume(user != address(0) && (lenderId < 2 || lenderId == 50));
        address asset = WMATIC;
        address collateralToken = collateralTokens[asset][lenderId];

        address borrowAsset = USDC;

        fundRouter(asset, borrowAsset);

        address debtToken = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 200.0e18;
            uint256 amountToLeverage = 100.0e6;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, 0);
        }

        uint256 amountToFlashWithdraw = 15.0e6;

        uint256 borrowBalance = IERC20All(debtToken).balanceOf(user);
        uint256 balance = IERC20All(collateralToken).balanceOf(user);
        bytes memory dataWithdraw;
        uint witdrawAm;
        {
            witdrawAm = amountToFlashWithdraw + (amountToFlashWithdraw * ILendingPool(AAVE_POOL).FLASHLOAN_PREMIUM_TOTAL()) / 10000;
            vm.prank(user);
            IERC20All(collateralToken).approve(brokerProxyAddress, witdrawAm);

            dataWithdraw = withdraw(asset, brokerProxyAddress, witdrawAm, lenderId);
        }

        {
            bytes memory data = repay(
                borrowAsset,
                user,
                0, // all, incl init depo
                lenderId,
                uint8(DEFAULT_IR_MODE)
            );

            data = encodeAaveV2FlashLoan(
                asset, // flash withdraw asset
                amountToFlashWithdraw,
                BALANCER_V2,
                abi.encodePacked(
                    encodeExtCall(
                        asset,
                        borrowAsset,
                        address(router),
                        address(router),
                        amountToFlashWithdraw //
                    ),
                    data, // repay
                    dataWithdraw
                ) //
            );

            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas-flash-loan-close", gas);
        }
        balance = balance - IERC20All(collateralToken).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtToken).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(witdrawAm, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(14999988, borrowBalance, 1);
    }

    function getOpenExactInInternal(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = ALGEBRA;
        console.log("t");
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        console.log("t", pool);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut, uint8(0), uint8(0));
    }

    function getCloseExactInInternal(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = ALGEBRA;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut, uint8(0), uint8(0));
    }

    function fundRouter(address a, address b) internal {
        deal(a, address(router), 1e20);
        deal(b, address(router), 1e20);
    }

    function encodeExtCall(address token, address tokenOut, address approveTarget, address target, uint amount) internal pure returns (bytes memory) {
        bytes memory data = abi.encodeWithSelector(MockRouter.swapExactIn.selector, token, tokenOut, amount);
        return
            abi.encodePacked(
                uint8(Commands.EXTERNAL_CALL), //
                token,
                approveTarget,
                target,
                uint112(amount),
                uint16(data.length),
                data
            );
    }
}
