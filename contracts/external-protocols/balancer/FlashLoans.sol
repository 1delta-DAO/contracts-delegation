// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

// This flash loan provider was based on the Aave protocol's open source
// implementation and terminology and interfaces are intentionally kept
// similar

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./IFlashLoanRecipient.sol";
import "./Fees.sol";
import "../openzeppelin/token/ERC20/IERC20.sol";

/**
 * @dev Handles Flash Loans through the Vault. Calls the `receiveFlashLoan` hook on the flash loan recipient
 * contract, which implements the `IFlashLoanRecipient` interface.
 */
abstract contract FlashLoans is Fees {
    function flashLoan(IFlashLoanRecipient recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData) external {
        require(tokens.length == amounts.length, "LENGTHS");

        uint256[] memory feeAmounts = new uint256[](tokens.length);
        uint256[] memory preLoanBalances = new uint256[](tokens.length);

        // Used to ensure `tokens` is sorted in ascending order, which ensures token uniqueness.
        address previousToken = address(0);

        for (uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 amount = amounts[i];

            require(token > previousToken, token == address(address(0)) ? "ZERO_TOKEN" : "UNSORTED_TOKENS");
            previousToken = token;

            preLoanBalances[i] = IERC20(token).balanceOf(address(this));
            feeAmounts[i] = _calculateFlashLoanFeeAmount(amount);

            require(preLoanBalances[i] >= amount, "INSUFFICIENT_FLASH_LOAN_BALANCE");
            SafeERC20.safeTransfer(token, address(recipient), amount);
        }

        recipient.receiveFlashLoan(tokens, amounts, feeAmounts, userData);

        for (uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 preLoanBalance = preLoanBalances[i];

            // Checking for loan repayment first (without accounting for fees) makes for simpler debugging, and results
            // in more accurate revert reasons if the flash loan protocol fee percentage is zero.
            uint256 postLoanBalance = IERC20(token).balanceOf(address(this));
            require(postLoanBalance >= preLoanBalance, "INVALID_POST_LOAN_BALANCE");

            // No need for checked arithmetic since we know the loan was fully repaid.
            uint256 receivedFeeAmount = postLoanBalance - preLoanBalance;
            require(receivedFeeAmount >= feeAmounts[i], "INSUFFICIENT_FLASH_LOAN_FEE_AMOUNT");

            _payFeeAmount(token, receivedFeeAmount);
        }
    }
}
