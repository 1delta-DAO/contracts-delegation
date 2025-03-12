// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@flash-account/common/FlashAccountError.sol";

/**
 * @title FlashAccountAdapterBase
 * @notice Abstract base contract for flash account adapters.
 * @dev Provides common functionality for flash account operations.
 */
abstract contract FlashAccountAdapterBase {
    address public constant NATIVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    address public immutable WETH;

    mapping(address => mapping(address => bool)) public isApprovedAddress;

    /**
     * @notice Constructor for the FlashAccountAdapterBase contract.
     * @param weth_ The address of the WETH token.
     */
    constructor(address weth_) {
        if (weth_ == ZERO_ADDRESS) revert ZeroAddress();
        WETH = weth_;
    }

    /**
     * @notice Internal function to transfer ERC20 tokens.
     * @param token The address of the ERC20 token.
     * @param receiver The address to receive the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _transferERC20(address token, address receiver, uint256 amount) internal virtual {
        if (amount > 0) {
            SafeERC20.safeTransfer(IERC20(token), receiver, amount);
        }
    }

    /**
     * @notice Internal function to transfer ERC20 tokens from a specified address.
     * @param token The address of the ERC20 token.
     * @param from The address to transfer tokens from.
     * @param receiver The address to receive the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _transferFromERC20(address token, address from, address receiver, uint256 amount) internal virtual {
        if (amount > 0) {
            SafeERC20.safeTransferFrom(IERC20(token), from, receiver, amount);
        }
    }

    /**
     * @notice Internal function to transfer native tokens to a specified address.
     * @param receiver The address to receive the native tokens.
     * @param amount The amount of native tokens to transfer.
     */
    function _transferNative(address receiver, uint256 amount) internal virtual {
        if (amount > 0 && address(this).balance >= amount) {
            (bool success, bytes memory returndata) = receiver.call{value: amount}("");
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }
    }

    /**
     * @notice Internal function to get the balance of a specified token for a given account.
     * @dev If the token is the zero address or the native address, the balance is returned as the account's balance.
     * @param token The address of the token.
     * @param account The address of the account to check the balance of.
     * @return The balance of the specified token for the given account.
     */
    function _getBalance(address token, address account) internal view returns (uint256) {
        if (token == ZERO_ADDRESS || token == NATIVE_ADDRESS) return account.balance;
        return IERC20(token).balanceOf(account);
    }

    /**
     * @notice Public function to wrap native tokens.
     * @param amount The amount of native tokens to wrap.
     */
    function _wrap(uint256 amount) internal virtual {
        if (_getBalance(ZERO_ADDRESS, address(this)) < amount) revert NotEnoughBalance();
        WETH.call{value: amount}(abi.encodeWithSignature("deposit()"));
    }

    /**
     * @notice Internal function to unwrap WETH.
     * @param amount The amount of WETH to unwrap.
     */
    function _unwrap(uint256 amount) internal virtual {
        if (amount == 0) revert ZeroAmount();
        WETH.call(abi.encodeWithSignature("withdraw(uint256)", amount));
    }
}
