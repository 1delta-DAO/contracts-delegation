// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FlashAccountAdapterBase} from "@flash-account/adapters/FlashAccountAdapterBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@flash-account/common/FlashAccountError.sol";

/**
 * @title UtilityAdapter
 * @notice This contract provides utility functions that can be used by adapters.
 */
contract UtilityAdapter is FlashAccountAdapterBase {
    /**
     * @notice Constructor for the UtilityAdapter contract.
     * @param weth_ The address of the WETH token.
     */
    constructor(address weth_) FlashAccountAdapterBase(weth_) {}
    /**
     * @notice Transfer ERC20 tokens to a specified address.
     * @param token The address of the ERC20 token to transfer.
     * @param to The address to transfer the tokens to.
     * @param amount The amount of tokens to transfer.
     * @dev If the amount is type(uint256).max, the balance of the token in the contract will be used.*/
    function transferERC20(address token, address to, uint256 amount) external {
        if (to == address(0) || token == address(0) || token.code.length == 0) revert ZeroAddress();

        if (amount == type(uint256).max) {
            amount = _getBalance(token, address(this));
        }

        if (amount == 0) revert ZeroAmount();

        _transferERC20(token, to, amount);
    }

    /**
     * @notice Transfer native tokens (ETH/AVAX) to a specified address.
     * @param to The address to transfer the native tokens to.
     * @param amount The amount of native tokens to transfer.
     * @dev If the amount is type(uint256).max, the balance of the native token in the contract will be used.
     */
    function transferNative(address to, uint256 amount) external {
        if (to == address(0)) revert ZeroAddress();

        if (amount == type(uint256).max) {
            amount = address(this).balance;
        }

        if (amount == 0) revert ZeroAmount();

        _transferNative(to, amount);
    }

    /**
     * @notice Transfer ERC20 tokens from a specified address to a specified address.
     * @param token The address of the ERC20 token to transfer.
     * @param from The address to transfer the tokens from.
     * @param to The address to transfer the tokens to.
     * @param amount The amount of tokens to transfer.
     * @dev If the amount is type(uint256).max, the allowance of the token from the from address will be used.
     */
    function transferFromERC20(address token, address from, address to, uint256 amount) external {
        if (from == address(0) || to == address(0) || token == address(0) || token.code.length == 0) revert ZeroAddress();
        if (amount == type(uint256).max) {
            amount = IERC20(token).allowance(from, address(this));
        }

        if (amount == 0) revert ZeroAmount();

        _transferFromERC20(token, from, to, amount);
    }

    /**
     * @notice Get the balance of a specified token for a specified address.
     * @dev If the token is the zero address, the balance of the native token will be returned.
     * @param token The address of the token to check the balance of.
     * @param account The address to check the balance of.
     * @return The balance of the specified token for the specified address.
     */
    function getBalance(address token, address account) external view returns (uint256) {
        return _getBalance(token, account);
    }
}
