// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import {MockRouter} from "../../contracts/mocks/MockRouter.sol";

contract ComposedFlashLoanTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable
    MockRouter router;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 62219594, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        router = new MockRouter(1.0e18, 12);

        intitializeFullDelta();

        management.approveAddress(getAssets(), address(router));
        management.setValidTarget(address(router), address(router), true);
    }

    /**
     * Transfers in
     * flash loan
     *  swap
     *  depoist
     *  borrow
     *  payback
     */
    function test_mantle_composed_flash_loan_open(uint8 lenderId) external /** address user, uint8 lenderId */ {
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
            uint borrowAm = params.swapAmount +
                (params.swapAmount * ILendingPool(LENDLE_POOL).FLASHLOAN_PREMIUM_TOTAL()) / //
                10000;
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
            0, // do not slippage check here
            true,
            getOpenExactInInternal(
                params.borrowAsset,
                params.collateralAsset //
            )
        );
        bytes memory data = abi.encodePacked(
            initTransfer,
            encodeFlashLoan(
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
        assertApproxEqAbs(borrowBalance, 20018000000000000000, 1);
    }

    function test_mantle_ext_call() external {
        address someAddr = vm.addr(0x324);
        address someOtherAddr = vm.addr(0x324);

        management.setValidTarget(someAddr, someOtherAddr, true);

        bool val = management.getIsValidTarget(someAddr, someOtherAddr);
        console.log(val);
    }

    function test_mantle_composed_flash_loan_close() external {
        uint8 lenderId = 0;
        address user = testUser;
        vm.assume(user != address(0) && lenderId < 2);
        address asset = USDC;
        address collateralToken = collateralTokens[asset][lenderId];

        address borrowAsset = USDT;

        fundRouter(asset, borrowAsset);

        address debtToken = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 10.0e6;
            uint256 amountToLeverage = 20.0e6;

            openSimple(user, asset, borrowAsset, amountToDeposit, amountToLeverage, 0);
        }

        uint256 amountToFlashWithdraw = 15.0e6;

        uint256 borrowBalance = IERC20All(debtToken).balanceOf(user);
        uint256 balance = IERC20All(collateralToken).balanceOf(user);
        bytes memory dataWithdraw;
        uint witdrawAm;
        {
            witdrawAm = amountToFlashWithdraw + (amountToFlashWithdraw * ILendingPool(LENDLE_POOL).FLASHLOAN_PREMIUM_TOTAL()) / 10000;
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

            data = encodeFlashLoan(
                asset, // flash withdraw asset
                amountToFlashWithdraw,
                lenderId,
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
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut, uint8(0), uint8(0));
    }

    function getCloseExactInInternal(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_LOW);
        uint8 poolId = AGNI;
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
