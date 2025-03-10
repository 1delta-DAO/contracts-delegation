// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FlashAccountAdapterBase} from "../../FlashAccountAdapterBase.sol";
import {IQiToken} from "./interfaces/IQiToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BenqiAdapter is FlashAccountAdapterBase {
    error ZeroAmount();
    error MintFailed(uint256 failureCode);
    error RepayFailed(uint256 failureCode);
    error CantRepaySelf();
    error TransferFailed();

    /**
     * @notice Supply assets to Benqi
     * @dev Handles both ERC20 tokens and native AVAX
     * @param qiToken The qiToken address to mint (qiUSDC for USDC, qiAVAX for AVAX, ...)
     * @param underlying The underlying token address (address 0 or 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE for native AVAX)
     * @param onbehalfOf The address that will receive the qiTokens
     * @return result 0 if successful, error code otherwise
     */
    function supply(address qiToken, address underlying, address onbehalfOf) external payable returns (uint256 result) {
        uint256 initialQiTokenBalance = _getERC20Balance(qiToken, address(this));

        // Handle native AVAX supply
        if ((underlying == NATIVE_ADDRESS || underlying == ZERO_ADDRESS)) {
            if (msg.value == 0) revert ZeroAmount();
            IQiToken(qiToken).mint{value: msg.value}();
        }
        // Handle ERC20 token supply
        else {
            uint256 amount = _getCurrentBalance(underlying);

            // check if token is approved
            if (!isApprovedAddress[underlying][qiToken]) {
                SafeERC20.safeIncreaseAllowance(IERC20(underlying), qiToken, type(uint256).max);
                isApprovedAddress[underlying][qiToken] = true;
            }

            result = IQiToken(qiToken).mint(amount);

            if (result != 0) revert MintFailed(result);

            // refund excess (if any)
            uint256 excess = IERC20(underlying).balanceOf(address(this));
            if (excess > 0) {
                _transferERC20(underlying, onbehalfOf, excess);
            }
        }

        uint256 finalQiTokenBalance = _getERC20Balance(qiToken, address(this));

        // transfer qiTokens to receiver
        _transferERC20(qiToken, onbehalfOf, finalQiTokenBalance - initialQiTokenBalance);

        return result; // 0 for success
    }

    /**
     * @notice Repay borrowed assets to Benqi
     * @dev Handles both ERC20 tokens and native AVAX
     * @param qiToken The qiToken address to repay (qiUSDC for USDC, qiAVAX for AVAX, ....)
     * @param underlying The underlying token address (address 0 or 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE for native AVAX)
     * @param borrower The address whose debt is being repaid
     * @param onbehalfOf The address that will receive any excess tokens
     * @return result 0 if successful, error code otherwise
     */
    function repay(address qiToken, address underlying, address borrower, address onbehalfOf) external payable returns (uint256 result) {
        // Handle native AVAX repay
        if (msg.value > 0 && (underlying == NATIVE_ADDRESS || underlying == ZERO_ADDRESS)) {
            uint256 initialBalance = address(this).balance;
            if (borrower == address(this)) {
                revert CantRepaySelf();
            } else {
                IQiToken(qiToken).repayBorrowBehalf{value: msg.value}(borrower);
            }

            // Refund any excess ETH
            uint256 balance = address(this).balance - initialBalance;
            if (balance > 0) {
                (bool success, ) = onbehalfOf.call{value: balance}("");
                if (!success) revert TransferFailed();
            }
        }
        // Handle ERC20 token repay
        else {
            uint256 amount = _getCurrentBalance(underlying);

            // check if token is approved
            if (!isApprovedAddress[underlying][qiToken]) {
                SafeERC20.safeIncreaseAllowance(IERC20(underlying), qiToken, type(uint256).max);
                isApprovedAddress[underlying][qiToken] = true;
            }

            if (borrower == address(this)) {
                revert CantRepaySelf();
            } else {
                result = IQiToken(qiToken).repayBorrowBehalf(borrower, amount);
            }

            if (result != 0) revert RepayFailed(result);

            // refund excess (if any)
            uint256 excess = IERC20(underlying).balanceOf(address(this));
            if (excess > 0) {
                _transferERC20(underlying, onbehalfOf, excess);
            }
        }

        return result; // 0 for success
    }

    function _getCurrentBalance(address token) internal view returns (uint256) {
        uint256 amount = _getERC20Balance(token, address(this));
        if (amount == 0) revert ZeroAmount();

        return amount;
    }
}
