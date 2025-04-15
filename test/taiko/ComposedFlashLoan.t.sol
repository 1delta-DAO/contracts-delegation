// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import {MockRouter} from "../../contracts/mocks/MockRouter.sol";

contract ComposedFlashLoanTestTaiko is DeltaSetup {
    uint256 internal constant DEFAULT_IR_MODE = 2; // variable
    uint8 internal constant DEFAULT_FLASH_LOAN_ID = 0; // meridian Aave V2 style
    MockRouter router;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 728223, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});

        router = new MockRouter(1.0e18, 12);

        intitializeFullDelta();

        management.approveAddress(getAssets(), address(router));
        management.setValidTarget(address(router), true);
    }

    /**
     * Transfers in
     * flash loan
     *  swap
     *  depoist
     *  borrow
     *  payback
     */
    function test_taiko_composed_flash_loan_open() external {
        uint16 lenderId = 1000;
        TestParamsOpen memory params;
        address user = testUser;
        vm.assume(user != address(0));
        vm.deal(user, 1.0e18);
        {
            address asset = TokensTaiko.WETH;

            address borrowAsset = TokensTaiko.TAIKO;
            deal(asset, user, 1e20);

            uint256 amountToDeposit = 0.001e18;

            uint256 amountToBorrow = 1.0e18;
            uint256 minimumOut = 1.0e6;
            params = getOpenParams(
                borrowAsset,
                asset,
                amountToDeposit,
                amountToBorrow,
                minimumOut, //6
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
            uint256 borrowAm = params.swapAmount
                + (params.swapAmount * ILendingPool(HanaTaiko.POOL).FLASHLOAN_PREMIUM_TOTAL()) //
                    / 10000;
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
                DEFAULT_FLASH_LOAN_ID,
                abi.encodePacked(swap, dataDeposit, dataBorrow) //
            )
        );

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();

        console.log("gas-flash-loan-open", gas);

        balance = IERC20All(params.collateralToken).balanceOf(user) - balance;
        borrowBalance = IERC20All(params.debtToken).balanceOf(user) - borrowBalance;

        // deposit 2, recieve 2.6... makes 4.6...
        assertApproxEqAbs(1473732329564486, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(borrowBalance, 1000500000000000000, 1);
    }

    function test_taiko_ext_call() external {
        address someAddr = vm.addr(0x324);

        management.setValidTarget(someAddr, true);

        bool val = management.getIsValidTarget(someAddr);
        console.log(val);
    }

    function test_taiko_composed_flash_loan_close() external {
        uint16 lenderId = 1000;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = TokensTaiko.WETH;
        address collateralToken = collateralTokens[asset][lenderId];

        address borrowAsset = TokensTaiko.TAIKO;

        fundRouter(asset, borrowAsset);

        address debtToken = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 0.001e18;
            uint256 amountToLeverage = 1.0e18;

            openSimple2(user, asset, borrowAsset, amountToDeposit, amountToLeverage, lenderId);
        }

        uint256 amountToFlashWithdraw = 0.00001e18;

        uint256 borrowBalance = IERC20All(debtToken).balanceOf(user);
        uint256 balance = IERC20All(collateralToken).balanceOf(user);
        bytes memory dataWithdraw;
        uint256 witdrawAm;
        {
            witdrawAm = amountToFlashWithdraw + (amountToFlashWithdraw * ILendingPool(HanaTaiko.POOL).FLASHLOAN_PREMIUM_TOTAL()) / 10000;
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
                DEFAULT_FLASH_LOAN_ID,
                abi.encodePacked(
                    encodeExtCall(
                        asset,
                        borrowAsset,
                        address(router),
                        amountToFlashWithdraw //
                    ),
                    data, // repay
                    dataWithdraw
                ) //
            );

            vm.prank(user);
            uint256 gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas-flash-loan-close", gas);
        }
        balance = balance - IERC20All(collateralToken).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtToken).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(witdrawAm, balance, 1e6);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(9999999999988, borrowBalance, 1);
    }

    function getOpenExactInInternal(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_HIGHEST;
        uint8 poolId = DexMappingsTaiko.IZUMI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut, uint8(0), uint8(0));
    }

    function getCloseExactInInternal(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_LOW;
        uint8 poolId = DexMappingsTaiko.UNI_V3;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut, uint8(0), uint8(0));
    }

    function fundRouter(address a, address b) internal {
        deal(a, address(router), 1e20);
        deal(b, address(router), 1e20);
    }

    function encodeExtCall(address token, address tokenOut, address target, uint256 amount) internal pure returns (bytes memory) {
        bytes memory data = abi.encodeWithSelector(MockRouter.swapExactIn.selector, token, tokenOut, amount);
        return abi.encodePacked(
            uint8(Commands.EXTERNAL_CALL), //
            token,
            target,
            uint112(amount),
            uint16(data.length),
            data
        );
    }

    function openSimple2(address user, address asset, address borrowAsset, uint256 depositAmount, uint256 borrowAmount, uint16 lenderId) internal {
        address debtAsset = debtTokens[borrowAsset][lenderId];
        deal(asset, user, depositAmount);

        bytes memory data = transferIn(asset, brokerProxyAddress, depositAmount);

        data = abi.encodePacked(
            data,
            deposit(asset, user, depositAmount, lenderId) //
        );

        bytes memory swapPath = getOpenExactInSingleIzi(borrowAsset, asset, lenderId);
        uint256 checkAmount = 0; // we do not care about slippage in that regard
        data = abi.encodePacked(
            data,
            encodeFlashSwap(
                Commands.FLASH_SWAP_EXACT_IN, // open
                borrowAmount,
                checkAmount,
                false,
                swapPath
            )
        );

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, depositAmount);
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, borrowAmount);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
    }

    function getOpenExactInSingleIzi(address tokenIn, address tokenOut, uint16 lenderId) internal view returns (bytes memory data) {
        uint16 fee = DEX_FEE_HIGHEST;
        uint8 poolId = DexMappingsTaiko.IZUMI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        (uint8 actionId,, uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, actionId, poolId, pool, fee, tokenOut, lenderId, endId);
    }
}
