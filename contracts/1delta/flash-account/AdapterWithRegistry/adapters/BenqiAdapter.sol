// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ILendingProvider} from "@flash-account/interfaces/ILendingProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CTokenSignatures} from "@flash-account/Lenders/Benqi/CTokenSignatures.sol";

contract BenqiAdapter is ILendingProvider, CTokenSignatures {
    error InsufficientBalance();
    error CantReadBalance();
    address constant BENQI_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;

    function supply(ILendingProvider.LendingParams calldata params) external override {
        uint256 amount = params.amount;
        if (params.amount == 0) {
            amount = IERC20(params.asset).balanceOf(address(this));
            if (amount == 0) revert InsufficientBalance();
        } else {
            IERC20(params.asset).transferFrom(params.caller, address(this), params.amount);
        }

        IERC20(params.asset).approve(params.collateralToken, amount);
        (bool success, ) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_MINT_SELECTOR, amount));
        require(success, "Mint failed");
    }

    /// @dev if amount is 0, we use get the balance of underlying and redeem_underlying, otherwise we use redeem
    function withdraw(ILendingProvider.LendingParams calldata params) external override {
        uint256 amount = params.amount;
        if (params.amount == 0) {
            // this also accrues interest
            (bool success, bytes memory data) = params.collateralToken.call(
                abi.encodeWithSelector(CTOKEN_BALANCE_OF_UNDERLYING_SELECTOR, address(this))
            );
            if (!success) revert CantReadBalance();
            amount = abi.decode(data, (uint256));

            (success, ) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_REDEEM_UNDERLYING_SELECTOR, amount));
            require(success, "Withdraw failed");
        } else {
            (bool success, ) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_REDEEM_SELECTOR, amount));
            require(success, "Withdraw failed");
        }

        // Transfer to caller
        if (params.caller != address(this)) {
            uint256 balance = IERC20(params.asset).balanceOf(address(this));
            IERC20(params.asset).transfer(params.caller, balance);
        }
    }

    function borrow(ILendingProvider.LendingParams calldata params) external override {
        (bool success, ) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_BORROW_SELECTOR, params.amount));
        require(success, "Borrow failed");

        // Transfer to caller
        if (params.caller != address(this)) {
            uint256 balance = IERC20(params.asset).balanceOf(address(this));
            IERC20(params.asset).transfer(params.caller, balance);
        }
    }

    /// @dev the flash-account should have enough balance to repay the loan
    function repay(ILendingProvider.LendingParams calldata params) external override {
        uint256 initBalance = IERC20(params.asset).balanceOf(address(this));
        if (initBalance == 0) revert InsufficientBalance();
        uint256 amount = params.amount;

        if (params.amount == 0) amount = initBalance;

        IERC20(params.asset).approve(params.collateralToken, amount);

        (bool success, bytes memory data) = params.collateralToken.call(abi.encodeWithSelector(CTOKEN_REPAY_BORROW_SELECTOR, params.amount));
        require(success, "Repay failed");

        uint256 repayAmount = abi.decode(data, (uint256));
        // refund
        if (initBalance < repayAmount) {
            IERC20(params.asset).transfer(params.caller, repayAmount - initBalance);
        }
    }
}
