// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

import {BaseLightAccountFactory} from "./common/BaseLightAccountFactory.sol";
import {LibClone} from "./proxy/LibClone.sol";
import {IBeacon} from "./proxy/IBeacon.sol";
import {FlashAccountBase} from "./FlashAccountBase.sol";

/// @title A factory contract for FlashAccount, baed on LightAccountFactory by Alchemy.
/// @dev A UserOperations "initCode" holds the address of the factory, and a method call (`createAccount`). The
/// factory's `createAccount` returns the target account address even if it is already installed. This way,
/// `entryPoint.getSenderAddress()` can be called either before or after the account is created.
contract FlashAccountFactory is BaseLightAccountFactory {
    address public immutable ACCOUNT_BEACON;

    constructor(address owner, address accountBeacon, IEntryPoint entryPoint) Ownable(owner) {
        _verifyEntryPointAddress(address(entryPoint));
        ACCOUNT_BEACON = accountBeacon;
        ENTRY_POINT = entryPoint;
    }

    /// @notice Create an account, and return its address. Returns the address even if the account is already deployed.
    /// @dev During UserOperation execution, this method is called only if the account is not deployed. This method
    /// returns an existing account address so that entryPoint.getSenderAddress() would work even after account
    /// creation.
    /// @param owner The owner of the account to be created.
    /// @param salt A salt, which can be changed to create multiple accounts with the same owner.
    /// @return account The address of either the newly deployed account or an existing account with this owner and salt.
    function createAccount(address owner, uint256 salt) external returns (FlashAccountBase account) {
        (bool alreadyDeployed, address accountAddress) = LibClone.createDeterministicERC1967IBeaconProxy(
            ACCOUNT_BEACON,
            _getCombinedSalt(owner, salt)
        );

        account = FlashAccountBase(payable(accountAddress));

        if (!alreadyDeployed) {
            account.initialize(owner);
        }
    }

    /// @notice Calculate the counterfactual address of this account as it would be returned by `createAccount`.
    /// @param owner The owner of the account to be created.
    /// @param salt A salt, which can be changed to create multiple accounts with the same owner.
    /// @return The address of the account that would be created with `createAccount`.
    function getAddress(address owner, uint256 salt) external view returns (address) {
        return LibClone.predictDeterministicAddressERC1967IBeaconProxy(address(ACCOUNT_BEACON), _getCombinedSalt(owner, salt), address(this));
    }

    /// @notice Get the account implementation provided by the beacon.
    /// @return The address provided by the beacon.
    function getAccountImplementation() external view returns (address) {
        return IBeacon(ACCOUNT_BEACON).implementation();
    }

    /// @notice Compute the hash of the owner and salt in scratch space memory.
    /// @dev The caller is responsible for cleaning the upper bits of the owner address parameter.
    /// @param owner The owner of the account to be created.
    /// @param salt A salt, which can be changed to create multiple accounts with the same owner.
    /// @return combinedSalt The hash of the owner and salt.
    function _getCombinedSalt(address owner, uint256 salt) internal pure returns (bytes32 combinedSalt) {
        // Compute the hash of the owner and salt in scratch space memory.
        assembly ("memory-safe") {
            mstore(0x00, owner)
            mstore(0x20, salt)
            combinedSalt := keccak256(0x00, 0x40)
        }
    }
}
