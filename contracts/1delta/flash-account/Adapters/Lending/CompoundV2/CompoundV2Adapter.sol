// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FlashAccountAdapterBase} from "../../FlashAccountAdapterBase.sol";
import {IcToken} from "./interfaces/IcToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CompoundV2Adapter is FlashAccountAdapterBase {
    error ZeroAmount();
    error MintFailed(uint256 failureCode);
    error RepayFailed(uint256 failureCode);
    error CantRepaySelf();
    error TransferFailed();
    error NotEnoughBalance();
    /**
     * @notice Supply ERC20 assets to CompoundV2
     * @param cToken The cToken address to mint (e.g., cUSDC)
     * @param underlying The underlying token address (e.g., USDC)
     * @param onbehalfOf The address that will receive the cTokens
     * @return result 0 if successful, error code otherwise
     */
    function supply(address cToken, address underlying, address onbehalfOf) external returns (uint256 result) {
        uint256 initialCTokenBalance = _getERC20Balance(cToken, address(this));

        uint256 availableBalance = _getERC20Balance(underlying, address(this));
        if (availableBalance == 0) revert ZeroAmount();

        // Check if token is approved
        if (!isApprovedAddress[underlying][cToken]) {
            SafeERC20.safeIncreaseAllowance(IERC20(underlying), cToken, type(uint256).max);
            isApprovedAddress[underlying][cToken] = true;
        }

        // Execute the mint
        result = IcToken(cToken).mint(availableBalance);
        if (result != 0) revert MintFailed(result);

        // Refund excess (if any)
        uint256 excess = IERC20(underlying).balanceOf(address(this));
        if (excess > 0) {
            _transferERC20(underlying, onbehalfOf, excess);
        }

        // Transfer cTokens to receiver
        uint256 finalCTokenBalance = _getERC20Balance(cToken, address(this));
        _transferERC20(cToken, onbehalfOf, finalCTokenBalance - initialCTokenBalance);

        return result; // 0 for success
    }

    /**
     * @notice Supply native tokens (ETH/AVAX) to CompoundV2
     * @param cToken The cToken address to mint (e.g., cETH)
     * @param onbehalfOf The address that will receive the cTokens
     * @return result 0 if successful, error code otherwise
     */
    function supplyValue(address cToken, address onbehalfOf) external payable returns (uint256 result) {
        if (msg.value == 0) revert ZeroAmount();

        uint256 initialCTokenBalance = _getERC20Balance(cToken, address(this));

        IcToken(cToken).mint{value: msg.value}();

        // Transfer cTokens to receiver
        uint256 finalCTokenBalance = _getERC20Balance(cToken, address(this));
        _transferERC20(cToken, onbehalfOf, finalCTokenBalance - initialCTokenBalance);

        // Refund any excess native tokens (if any)
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = onbehalfOf.call{value: balance}("");
            if (!success) revert TransferFailed();
        }

        return 0; // Success
    }

    /**
     * @notice Repay a borrow with ERC20 tokens
     * @param cToken The cToken address (e.g., cUSDC)
     * @param underlying The underlying token address (e.g., USDC)
     * @param borrower The address whose debt is being repaid
     * @param onbehalfOf The address that will receive any excess tokens
     * @param amount The amount to repay (use type(uint256).max for full repayment)
     * @return result 0 if successful
     */
    function repay(address cToken, address underlying, address borrower, address onbehalfOf, uint256 amount) external returns (uint256 result) {
        if (borrower == address(this)) revert CantRepaySelf();

        uint256 availableBalance = IERC20(underlying).balanceOf(address(this));
        if (availableBalance == 0) revert ZeroAmount();

        uint256 borrowBalance = IcToken(cToken).borrowBalanceCurrent(borrower);

        if (!isApprovedAddress[underlying][cToken]) {
            SafeERC20.safeIncreaseAllowance(IERC20(underlying), cToken, type(uint256).max);
            isApprovedAddress[underlying][cToken] = true;
        }

        uint256 repayAmount;

        // Full repayment requested
        if (amount == type(uint256).max) {
            // Partial repayment (all available balance)
            if (availableBalance < borrowBalance) {
                repayAmount = availableBalance;
            }
            // Full repayment
            else {
                repayAmount = borrowBalance;
            }
        }
        // Specific amount requested
        else {
            // Can only repay what we have
            if (availableBalance < amount) {
                repayAmount = availableBalance;
            }
            // Can repay the requested amount
            else {
                repayAmount = amount > borrowBalance ? borrowBalance : amount;
            }
        }

        result = IcToken(cToken).repayBorrowBehalf(borrower, repayAmount);

        if (result != 0) revert RepayFailed(result);

        // Refund any excess
        uint256 excess = IERC20(underlying).balanceOf(address(this));
        if (excess > 0) {
            _transferERC20(underlying, onbehalfOf, excess);
        }

        return 0;
    }

    /**
     * @notice Repay a borrow with native tokens (ETH/AVAX)
     * @param cToken The cToken address (e.g., cETH)
     * @param borrower The address whose debt is being repaid
     * @param onbehalfOf The address that will receive any excess tokens
     * @param amount The amount to repay (use type(uint256).max for full repayment)
     * @return result 0 if successful
     */
    function repayValue(address cToken, address borrower, address onbehalfOf, uint256 amount) external payable returns (uint256 result) {
        if (msg.value == 0) revert ZeroAmount();
        if (borrower == address(this)) revert CantRepaySelf();

        uint256 initialBalance = address(this).balance;
        uint256 borrowBalance = IcToken(cToken).borrowBalanceCurrent(borrower);

        uint256 repayAmount;

        // Full repayment requested
        if (amount == type(uint256).max) {
            // Partial repayment (all available balance)
            if (initialBalance < borrowBalance) {
                repayAmount = initialBalance;
            }
            // Full repayment
            else {
                repayAmount = borrowBalance;
            }
        }
        // Specific amount requested
        else {
            // Can only repay what we have
            if (initialBalance < amount) {
                repayAmount = initialBalance;
            }
            // Can repay the requested amount
            else {
                repayAmount = amount > borrowBalance ? borrowBalance : amount;
            }
        }

        IcToken(cToken).repayBorrowBehalf{value: repayAmount}(borrower);

        // Refund any excess
        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            _transferNative(onbehalfOf, remainingBalance);
        }

        return 0;
    }

    function _getCurrentBalance(address token) internal view returns (uint256) {
        uint256 amount = _getERC20Balance(token, address(this));
        if (amount == 0) revert ZeroAmount();

        return amount;
    }
}
