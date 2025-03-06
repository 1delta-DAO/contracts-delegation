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

    function supply(address qiToken, address underlying, address onbehalfOf) external returns (uint256) {
        uint256 initialQiTokenBalance = _getERC20Balance(qiToken, address(this));
        uint256 amount = _getCurrentBalance(underlying);

        SafeERC20.safeIncreaseAllowance(IERC20(underlying), qiToken, amount);

        uint256 result = IQiToken(qiToken).mint(amount);

        if (result != 0) revert MintFailed(result);

        // refund excess (if any)
        uint256 excess = IERC20(underlying).balanceOf(address(this));
        if (excess > 0) {
            _transferERC20(underlying, onbehalfOf, excess);
        }
        uint256 finalQiTokenBalance = _getERC20Balance(qiToken, address(this));

        // transfer qiTokens to receiver
        _transferERC20(qiToken, onbehalfOf, finalQiTokenBalance - initialQiTokenBalance);
        // todo: we need to see if it is required to return 0 in case everything is successful
        return result; // which is zero
    }

    function repay(address qiToken, address underlying, address borrower, address onbehalfOf) external returns (uint256) {
        uint256 amount = _getCurrentBalance(underlying);

        SafeERC20.safeIncreaseAllowance(IERC20(underlying), qiToken, amount);

        uint256 repayResult;
        if (borrower == address(this)) {
            repayResult = IQiToken(qiToken).repayBorrow(amount);
        } else {
            repayResult = IQiToken(qiToken).repayBorrowBehalf(borrower, amount);
        }

        if (repayResult != 0) revert RepayFailed(repayResult);

        // refund excess (if any)
        uint256 excess = IERC20(underlying).balanceOf(address(this));
        if (excess > 0) {
            _transferERC20(underlying, onbehalfOf, excess);
        }

        // todo: we need to see if it is required to return 0 in case everything is successful
        return repayResult; // which is zero
    }

    function _getCurrentBalance(address token) internal view returns (uint256) {
        uint256 amount = _getERC20Balance(token, address(this));
        if (amount == 0) revert ZeroAmount();

        return amount;
    }
}
