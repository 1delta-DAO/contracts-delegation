// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/******************************************************************************\
* Author: Achthar
/******************************************************************************/

// solhint-disable max-line-length

/// @title Abstract module for handling transfers related to a lending protocol
abstract contract BaseLendingBroker {
    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal virtual;

    /// @param token The token to pay
    /// @param valueToDeposit The amount to deposit
    function mintPrivate(address token, uint256 valueToDeposit) internal virtual;

    /// @param token The token to pay
    /// @param valueToWithdraw The amount to withdraw
    function withdrawPrivate(
        address token,
        uint256 valueToWithdraw,
        address recipient
    ) internal virtual;

    /// @param token The token to redeem
    /// @notice redeems full balance of cToken and returns the amount of underlying withdrawn
    function withdrawAll(address token, address recipient) internal virtual returns (uint256);

    /// @param token The token to pay
    /// @param valueToBorrow The amount to borrow
    function borrowPrivate(
        address token,
        uint256 valueToBorrow,
        address recipient
    ) internal virtual;

    /// @param token The token to pay
    /// @param valueToRepay The amount to repay
    function repayPrivate(address token, uint256 valueToRepay) internal virtual;

    // optional overrides - includes handling Ether and ERC20s
    function balanceOfUnderlying(address underlying) internal virtual returns (uint256) {}

    function borrowBalanceCurrent(address underlying) internal virtual returns (uint256) {}
}
