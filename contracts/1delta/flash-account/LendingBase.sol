// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ILendingProvider} from "@flash-account/interfaces/ILendingProvider.sol";
import {LendingAdapterRegistry} from "./LendingAdapterRegistry.sol";

/**
 * @title LendingBase
 * @notice Base contract for lending operations that uses adapters for different lending protocols
 * @dev Implements core lending functions and delegates calls to appropriate adapters
 */
abstract contract LendingBase {
    /// @notice Registry contract that manages lending adapters
    LendingAdapterRegistry public immutable lendingAdapterRegistry;

    /// @notice Custom errors
    error InvalidLendingAdapterRegistry();
    error AdapterNotRegistered();

    /**
     * @notice Contract constructor
     * @param lendingAdapterRegistry_ Address of the lending adapter registry
     */
    constructor(address lendingAdapterRegistry_) {
        if (lendingAdapterRegistry_ == address(0)) revert InvalidLendingAdapterRegistry();
        lendingAdapterRegistry = LendingAdapterRegistry(lendingAdapterRegistry_);
    }

    /**
     * @notice Get the balance of a token for the caller's adapter
     * @param token Address of the token to check balance for
     * @return uint256 Balance of the token
     */
    function balanceOf(address token) external view returns (uint256) {
        address adapter = lendingAdapterRegistry.getAdapter(msg.sender);
        if (adapter == address(0)) revert AdapterNotRegistered();
        return ILendingProvider(adapter).balanceOf(token);
    }

    /**
     * @notice Borrow assets from a lending protocol
     * @param params Struct containing borrow parameters
     */
    function borrow(ILendingProvider.LendingParams calldata params) external {
        address adapter = lendingAdapterRegistry.getAdapter(params.lender);
        if (adapter == address(0)) revert AdapterNotRegistered();

        ILendingProvider(adapter).borrow(params);
        emit ILendingProvider.Borrowed(params.caller, params.asset, params.amount);
    }

    /**
     * @notice Repay borrowed assets to a lending protocol
     * @param params Struct containing repay parameters
     */
    function repay(ILendingProvider.LendingParams calldata params) external {
        address adapter = lendingAdapterRegistry.getAdapter(params.lender);
        if (adapter == address(0)) revert AdapterNotRegistered();

        ILendingProvider(adapter).repay(params);
        emit ILendingProvider.Repaid(params.caller, params.asset, params.amount);
    }

    /**
     * @notice Supply assets to a lending protocol
     * @param params Struct containing supply parameters
     */
    function supply(ILendingProvider.LendingParams calldata params) external {
        address adapter = lendingAdapterRegistry.getAdapter(params.lender);
        if (adapter == address(0)) revert AdapterNotRegistered();

        ILendingProvider(adapter).supply(params);
        emit ILendingProvider.Supplied(params.caller, params.asset, params.amount);
    }

    /**
     * @notice Withdraw supplied assets from a lending protocol
     * @param params Struct containing withdrawal parameters
     */
    function withdraw(ILendingProvider.LendingParams calldata params) external {
        address adapter = lendingAdapterRegistry.getAdapter(params.lender);
        if (adapter == address(0)) revert AdapterNotRegistered();

        ILendingProvider(adapter).withdraw(params);
        emit ILendingProvider.Withdrawn(params.caller, params.asset, params.amount);
    }
}
