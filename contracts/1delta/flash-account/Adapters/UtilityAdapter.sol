// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FlashAccountAdapterBase} from "./FlashAccountAdapterBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UtilityAdapter is FlashAccountAdapterBase {
    error ZeroAddress();
    error ZeroAmount();

    function transferERC20(address token, address to, uint256 amount) external {
        if (to == address(0) || token == address(0) || token.code.length == 0) revert ZeroAddress();

        if (amount == type(uint256).max) {
            amount = _getERC20Balance(token, address(this));
        }

        if (amount == 0) revert ZeroAmount();

        _transferERC20(token, to, amount);
    }

    function transferNative(address to, uint256 amount) external {
        if (to == address(0)) revert ZeroAddress();

        if (amount == type(uint256).max) {
            amount = address(this).balance;
        }

        if (amount == 0) revert ZeroAmount();

        _transferNative(to, amount);
    }

    function transferFromERC20(address token, address from, address to, uint256 amount) external {
        if (from == address(0) || to == address(0) || token == address(0) || token.code.length == 0) revert ZeroAddress();

        if (amount == type(uint256).max) {
            amount = IERC20(token).allowance(from, address(this));
        }

        if (amount == 0) revert ZeroAmount();

        _transferFromERC20(token, from, to, amount);
    }

    function getERC20Balance(address token, address account) external view returns (uint256) {
        if (token == address(0) || token.code.length == 0) revert ZeroAddress();
        return _getERC20Balance(token, account);
    }
}
