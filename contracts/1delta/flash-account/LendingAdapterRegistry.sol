// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LendingAdapterRegistry
 * @notice Registry for lending adapters with efficient lookup by both address and index
 * @dev Uses bytes4 hash of adapter address as index for quick lookup
 */
contract LendingAdapterRegistry is Ownable {
    /// @notice Mapping from lender address to adapter address
    mapping(address => address) private _adaptersByIndex;

    address[] private _registeredAdapters;

    error AdapterAlreadyRegistered();
    error AdapterNotRegistered();
    error InvalidAdapter();
    error InvalidIndex();

    event AdapterRegistered(address indexed adapter, address indexed index);
    event AdapterRemoved(address indexed adapter, address indexed index);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Register a new lending adapter
     * @param adapter Address of the adapter to register
     */
    function registerAdapter(address adapter, address lender) external onlyOwner {
        if (adapter == address(0)) revert InvalidAdapter();

        if (_adaptersByIndex[lender] != address(0)) revert AdapterAlreadyRegistered();

        _adaptersByIndex[lender] = adapter;
        _registeredAdapters.push(adapter);

        emit AdapterRegistered(adapter, lender);
    }

    /**
     * @notice Remove a lending adapter from the registry
     * @param lender The lender address
     */
    function removeAdapter(address lender) external onlyOwner {
        if (lender == address(0)) revert InvalidAdapter();

        if (_adaptersByIndex[lender] == address(0)) revert AdapterNotRegistered();
        address adapter = _adaptersByIndex[lender];
        delete _adaptersByIndex[lender];

        for (uint256 i = 0; i < _registeredAdapters.length; i++) {
            if (_registeredAdapters[i] == adapter) {
                _registeredAdapters[i] = _registeredAdapters[_registeredAdapters.length - 1];
                _registeredAdapters.pop();
                break;
            }
        }

        emit AdapterRemoved(adapter, lender);
    }

    /**
     * @notice Get adapter address by its index
     * @param lender The lender address
     * @return address the adapter address
     */
    function getAdapter(address lender) external view returns (address) {
        if (lender == address(0)) revert InvalidIndex();
        return _adaptersByIndex[lender];
    }

    /**
     * @notice Get all registered adapters
     * @return Array of registered adapter addresses
     */
    function getAllAdapters() external view returns (address[] memory) {
        return _registeredAdapters;
    }
}
