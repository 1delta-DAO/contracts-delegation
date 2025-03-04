// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LendingAdapterRegistry is Ownable {
    mapping(address => address) private _adaptersByLender;

    address[] private _registeredAdapters;

    error AdapterAlreadyRegistered();
    error AdapterNotRegistered();
    error InvalidAdapter();
    error InvalidLender();

    event AdapterRegistered(address indexed adapter, address indexed lender);
    event AdapterRemoved(address indexed adapter, address indexed lender);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Register a new lending adapter
     * @param adapter Address of the adapter to register
     * @param lender Address of the lender (e.g., Benqi Comptroller)
     */
    function registerAdapter(address adapter, address lender) external onlyOwner {
        if (adapter == address(0)) revert InvalidAdapter();
        if (lender == address(0)) revert InvalidLender();

        if (_adaptersByLender[lender] != address(0)) revert AdapterAlreadyRegistered();

        _adaptersByLender[lender] = adapter;
        _registeredAdapters.push(adapter);

        emit AdapterRegistered(adapter, lender);
    }

    /**
     * @notice Remove a lending adapter from the registry
     * @param lender Address of the lender
     */
    function removeAdapter(address lender) external onlyOwner {
        address adapter = _adaptersByLender[lender];
        if (adapter == address(0)) revert AdapterNotRegistered();

        delete _adaptersByLender[lender];

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
     * @notice Get adapter address by lender
     * @param lender The lender address
     * @return The adapter address
     */
    function getAdapter(address lender) external view returns (address) {
        return _adaptersByLender[lender];
    }

    /**
     * @notice Get all registered adapters
     * @return Array of registered adapter addresses
     */
    function getAllAdapters() external view returns (address[] memory) {
        return _registeredAdapters;
    }

    /**
     * @notice Check if a lender has a registered adapter
     * @param lender The lender address to check
     * @return bool indicating if the lender has a registered adapter
     */
    function hasAdapter(address lender) external view returns (bool) {
        return _adaptersByLender[lender] != address(0);
    }
}
