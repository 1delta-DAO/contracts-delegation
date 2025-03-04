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
    address internal _lendingAdapterRegistry;

    error InvalidLendingAdapterRegistry();
    error AdapterNotRegistered();
    error DelegateCallFailed();

    event AdapterCalled(address indexed adapter, bytes4 indexed selector);

    /**
     * @param lendingAdapterRegistry_ Address of the lending adapter registry
     */
    constructor(address lendingAdapterRegistry_) {
        if (lendingAdapterRegistry_ == address(0)) revert InvalidLendingAdapterRegistry();
        _lendingAdapterRegistry = lendingAdapterRegistry_;
    }

    function getLendingAdapterRegistry() public view returns (address) {
        return _lendingAdapterRegistry;
    }

    /**
     * @notice Borrow assets from a lending protocol
     * @param params Struct containing borrow parameters
     */
    function borrow(ILendingProvider.LendingParams calldata params) external {
        LendingAdapterRegistry registry = LendingAdapterRegistry(_lendingAdapterRegistry);
        address adapter = registry.getAdapter(params.lender);
        if (adapter == address(0)) revert AdapterNotRegistered();

        (bool success, bytes memory returnData) = adapter.delegatecall(abi.encodeWithSelector(ILendingProvider.borrow.selector, params));

        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        emit ILendingProvider.Borrowed(params.caller, params.asset, params.amount);
        emit AdapterCalled(adapter, ILendingProvider.borrow.selector);
    }

    /**
     * @notice Repay borrowed assets to a lending protocol
     * @param params Struct containing repay parameters
     */
    function repay(ILendingProvider.LendingParams calldata params) external {
        LendingAdapterRegistry registry = LendingAdapterRegistry(_lendingAdapterRegistry);
        address adapter = registry.getAdapter(params.lender);
        if (adapter == address(0)) revert AdapterNotRegistered();

        (bool success, bytes memory returnData) = adapter.delegatecall(abi.encodeWithSelector(ILendingProvider.repay.selector, params));

        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        emit ILendingProvider.Repaid(params.caller, params.asset, params.amount);
        emit AdapterCalled(adapter, ILendingProvider.repay.selector);
    }

    /**
     * @notice Supply assets to a lending protocol
     * @param params Struct containing supply parameters
     */
    function supply(ILendingProvider.LendingParams calldata params) external {
        LendingAdapterRegistry registry = LendingAdapterRegistry(_lendingAdapterRegistry);
        address adapter = registry.getAdapter(params.lender);
        if (adapter == address(0)) revert AdapterNotRegistered();

        (bool success, bytes memory returnData) = adapter.delegatecall(abi.encodeWithSelector(ILendingProvider.supply.selector, params));

        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        emit ILendingProvider.Supplied(params.caller, params.asset, params.amount);
        emit AdapterCalled(adapter, ILendingProvider.supply.selector);
    }

    /**
     * @notice Withdraw supplied assets from a lending protocol
     * @param params Struct containing withdrawal parameters
     */
    function withdraw(ILendingProvider.LendingParams calldata params) external {
        LendingAdapterRegistry registry = LendingAdapterRegistry(_lendingAdapterRegistry);
        address adapter = registry.getAdapter(params.lender);
        if (adapter == address(0)) revert AdapterNotRegistered();

        (bool success, bytes memory returnData) = adapter.delegatecall(abi.encodeWithSelector(ILendingProvider.withdraw.selector, params));

        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        emit ILendingProvider.Withdrawn(params.caller, params.asset, params.amount);
        emit AdapterCalled(adapter, ILendingProvider.withdraw.selector);
    }
}
