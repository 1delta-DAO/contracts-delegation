// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {SIG_VALIDATION_FAILED} from "account-abstraction/core/Helpers.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {BaseLightAccount} from "./common/BaseLightAccount.sol";
import {CustomSlotInitializable} from "./common/CustomSlotInitializable.sol";

/// @title A simple ERC-4337 compatible smart contract account with a designated owner account.
/// @dev Edited Alchemy `LightAccount` version, but with the following changes:
///
/// 1. Remove UUPSUpgradable pattern and use the BeaconProxy pattern instead
///
/// 2. Add `ExecutionLock` to `execute`, `executeBatch` adn `create` functions that enable an unlock flag
///
/// 3. Add explicit flash loan receiver callbacks that are only accesible if the unlock flag is accordingly set
///
contract FlashAccountBase is BaseLightAccount, CustomSlotInitializable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /// @dev The storage layout must stay consistent for all implementatiobns

    /// @dev keccak256("flash_account.storage");
    bytes32 internal constant _STORAGE_POSITION = 0xfe43cac86d2632475e173babfc884cd7f9ce21169af8b16db096c27563e34c09;
    /// @dev keccak256("flash_account.initializable");
    bytes32 internal constant _INITIALIZABLE_STORAGE_POSITION =
        0x5886a89854f64cffde2e739819f75451c42a85563516fe8eab2ef059d7e9f526;

    struct FlashAccountStorage {
        address owner;
    }

    /// @notice Emitted when this account is first initialized.
    /// @param entryPoint The entry point.
    /// @param owner The initial owner.
    event LightAccountInitialized(IEntryPoint indexed entryPoint, address indexed owner);

    /// @notice Emitted when this account's owner changes. Also emitted once at initialization, with a
    /// `previousOwner` of 0.
    /// @param previousOwner The previous owner.
    /// @param newOwner The new owner.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev The new owner is not a valid owner (e.g., `address(0)`, the account itself, or the current owner).
    error InvalidOwner(address owner);

    constructor(IEntryPoint entryPoint_) CustomSlotInitializable(_INITIALIZABLE_STORAGE_POSITION) {
        _ENTRY_POINT = entryPoint_;
        _disableInitializers();
    }

    /// @notice Called once as part of initialization, either during initial deployment or when first upgrading to
    /// this contract.
    /// @dev The `_ENTRY_POINT` member is immutable, to reduce gas consumption. To update the entry point address, a new
    /// implementation of LightAccount must be deployed with the new entry point address, and then `upgradeToAndCall`
    /// must be called to upgrade the implementation.
    /// @param owner_ The initial owner of the account.
    function initialize(address owner_) external virtual initializer {
        _initialize(owner_);
    }

    /// @notice Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current
    /// owner or from the entry point via a user operation signed by the current owner.
    /// @param newOwner The new owner.
    function transferOwnership(address newOwner) external virtual onlyAuthorized {
        if (newOwner == address(0) || newOwner == address(this)) {
            revert InvalidOwner(newOwner);
        }
        _transferOwnership(newOwner);
    }

    /// @notice Return the current owner of this account.
    /// @return The current owner.
    function owner() public view returns (address) {
        return _getStorage().owner;
    }

    function _initialize(address owner_) internal virtual {
        if (owner_ == address(0)) {
            revert InvalidOwner(address(0));
        }
        _getStorage().owner = owner_;
        emit LightAccountInitialized(_ENTRY_POINT, owner_);
        emit OwnershipTransferred(address(0), owner_);
    }

    function _transferOwnership(address newOwner) internal virtual {
        FlashAccountStorage storage _storage = _getStorage();
        address oldOwner = _storage.owner;
        if (newOwner == oldOwner) {
            revert InvalidOwner(newOwner);
        }
        _storage.owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @dev Implement template method of BaseAccount.
    /// Uses a modified version of `SignatureChecker.isValidSignatureNow` in which the digest is wrapped with an
    /// "Ethereum Signed Message" envelope for the EOA-owner case but not in the ERC-1271 contract-owner case.
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        if (userOp.signature.length < 1) {
            revert InvalidSignatureType();
        }
        uint8 signatureType = uint8(userOp.signature[0]);
        if (signatureType == uint8(SignatureType.EOA)) {
            // EOA signature
            bytes32 signedHash = userOpHash.toEthSignedMessageHash();
            bytes memory signature = userOp.signature[1:];
            return _successToValidationData(_isValidEOAOwnerSignature(signedHash, signature));
        } else if (signatureType == uint8(SignatureType.CONTRACT)) {
            // Contract signature without address
            bytes memory signature = userOp.signature[1:];
            return _successToValidationData(_isValidContractOwnerSignatureNow(userOpHash, signature));
        }
        revert InvalidSignatureType();
    }

    /// @notice Check if the signature is a valid by the EOA owner for the given digest.
    /// @dev Only supports 65-byte signatures, and uses the digest directly. Reverts if the signature is malformed.
    /// @param digest The digest to be checked.
    /// @param signature The signature to be checked.
    /// @return True if the signature is valid and by the owner, false otherwise.
    function _isValidEOAOwnerSignature(bytes32 digest, bytes memory signature) internal view returns (bool) {
        address recovered = digest.recover(signature);
        return recovered == owner();
    }

    /// @notice Check if the signature is a valid ERC-1271 signature by a contract owner for the given digest.
    /// @param digest The digest to be checked.
    /// @param signature The signature to be checked.
    /// @return True if the signature is valid and by an owner, false otherwise.
    function _isValidContractOwnerSignatureNow(bytes32 digest, bytes memory signature) internal view returns (bool) {
        return SignatureChecker.isValidERC1271SignatureNow(owner(), digest, signature);
    }

    /// @dev The signature is valid if it is signed by the owner's private key (if the owner is an EOA) or if it is a
    /// valid ERC-1271 signature from the owner (if the owner is a contract). Reverts if the signature is malformed.
    /// Note that unlike the signature validation used in `validateUserOp`, this does **not** wrap the hash in an
    /// "Ethereum Signed Message" envelope before checking the signature in the EOA-owner case.
    function _isValidSignature(bytes32 replaySafeHash, bytes calldata signature)
        internal
        view
        virtual
        override
        returns (bool)
    {
        if (signature.length < 1) {
            revert InvalidSignatureType();
        }
        uint8 signatureType = uint8(signature[0]);
        if (signatureType == uint8(SignatureType.EOA)) {
            // EOA signature
            return _isValidEOAOwnerSignature(replaySafeHash, signature[1:]);
        } else if (signatureType == uint8(SignatureType.CONTRACT)) {
            // Contract signature without address
            return _isValidContractOwnerSignatureNow(replaySafeHash, signature[1:]);
        }
        revert InvalidSignatureType();
    }

    function _domainNameAndVersion()
        internal
        view
        virtual
        override
        returns (string memory name, string memory version)
    {
        name = "FlashAccount";
        // Set to the major version of the GitHub release at which the contract was last updated.
        version = "1";
    }

    function _isFromOwner() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

    function _getStorage() internal pure returns (FlashAccountStorage storage storageStruct) {
        bytes32 position = _STORAGE_POSITION;
        assembly ("memory-safe") {
            storageStruct.slot := position
        }
    }
}
