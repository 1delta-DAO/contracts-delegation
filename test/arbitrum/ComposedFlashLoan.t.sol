// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ComposedFlashLoanTestArbitrum is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    /**
     * Transfers in
     * flash loan
     *  swap
     *  depoist
     *  borrow
     *  payback
     */
    function test_arbitrum_composed_flash_loan_open(uint16 lenderId) external /** address user, uint16 lenderId */ {
        TestParamsOpen memory params;
        address user = testUser;

        vm.assume((user != address(0) && lenderId == LenderMappingsArbitrum.AAVE_V3) || lenderId == LenderMappingsArbitrum.VENUS);
        vm.deal(user, 1.0e18);
        {
            address asset = TokensArbitrum.WETH;
            enterMarket(user, asset, lenderId);

            address borrowAsset = TokensArbitrum.USDT;

            uint256 amountToDeposit = 1.0e18;
            deal(asset, user, amountToDeposit);

            uint256 amountToBorrow = 2000.0e6; // need to borrow at least 100 for C3
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

        uint8 flashSource = FlashMappingsArbitrum.BALANCER_V2;
        {
            uint borrowAm = params.swapAmount +
                (params.swapAmount * getFlashFee(flashSource)) / //
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
            encodeFlashLoan(
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
        assertApproxEqAbs(1599889575762086734, balance, 1e10);
        {
            uint borrowAm = params.swapAmount +
                (params.swapAmount * getFlashFee(flashSource)) / //
                10000;
            // deviations through rouding expected, accuracy for 10 decimals
            assertApproxEqAbs(borrowBalance, borrowAm, 1);
        }
    }

    function test_arbitrum_ext_call() external {
        address someAddr = vm.addr(0x324);
        address someOtherAddr = vm.addr(0x324);

        management.setValidTarget(someAddr, someOtherAddr, true);

        bool val = management.getIsValidTarget(someAddr, someOtherAddr);
        console.log(val);
    }

    function test_arbitrum_composed_flash_loan_close(uint16 lenderId) external {
        address user = testUser;
        vm.assume(user != address(0) && (lenderId == LenderMappingsArbitrum.AAVE_V3 || lenderId == LenderMappingsArbitrum.VENUS));
        address asset = TokensArbitrum.WETH;
        enterMarket(user, asset, lenderId);

        uint8 flashSource = FlashMappingsArbitrum.BALANCER_V2;
        address borrowAsset = TokensArbitrum.USDT;

        fundRouter(asset, borrowAsset);
        router.setRate(333333333);
        {
            uint256 amountToDeposit = 1.0e18;
            uint256 amountToLeverage = 2000.0e6;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        uint256 amountToFlashWithdraw = 0.3e18;

        uint256 borrowBalance = getBorrowBalance(user, borrowAsset, lenderId);
        uint256 balance = getCollateralBalance(user, asset, lenderId);
        bytes memory data;
        uint witdrawAm;
        {
            witdrawAm = amountToFlashWithdraw + (amountToFlashWithdraw * getFlashFee(flashSource)) / 10000;
            approveWithdrawal(user, asset, witdrawAm, lenderId);
            data = withdraw(asset, BALANCER_VAULT, witdrawAm, lenderId);
        }

        {
            data = abi.encodePacked(
                repay(
                    borrowAsset,
                    user,
                    0, // all, incl init depo
                    lenderId,
                    uint8(DEFAULT_IR_MODE)
                ),
                data
            );

            data = encodeFlashLoan(
                asset, // flash withdraw asset
                amountToFlashWithdraw,
                flashSource,
                abi.encodePacked(
                    encodeExtCall(
                        asset,
                        borrowAsset,
                        address(router),
                        amountToFlashWithdraw //
                    ),
                    data // repay
                ) //
            );
            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas-flash-loan-close", gas);
        }
        balance = balance - getCollateralBalance(user, asset, lenderId);
        borrowBalance = borrowBalance - getBorrowBalance(user, borrowAsset, lenderId);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(witdrawAm, balance, 1e10);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(99999987, borrowBalance, 1);
    }

    function getOpenExactInInternal(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        uint8 poolId = DexMappingsArbitrum.PANCAKE;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut, uint16(0), uint8(0));
    }

    function getCloseExactInInternal(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_STABLES;
        uint8 poolId = DexMappingsArbitrum.PANCAKE;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut, uint16(0), uint8(0));
    }

    function fundRouter(address a, address b) internal {
        deal(a, address(router), 1e20);
        deal(b, address(router), 1e20);
    }

    function encodeExtCall(address token, address tokenOut, address target, uint amount) internal pure returns (bytes memory) {
        bytes memory data = abi.encodeWithSelector(MockRouter.swapExactIn.selector, token, tokenOut, amount);
        return
            abi.encodePacked(
                uint8(Commands.EXTERNAL_CALL), //
                token,
                target,
                uint112(amount),
                uint16(data.length),
                data
            );
    }

    function getFlashFee(uint8 source) internal view returns (uint) {
        return source == FlashMappingsArbitrum.BALANCER_V2 ? 0 : ILendingPool(AaveV3Arbitrum.POOL).FLASHLOAN_PREMIUM_TOTAL();
    }
}
