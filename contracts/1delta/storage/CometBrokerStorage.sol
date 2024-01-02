// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

// We do not use an array of stucts to avoid pointer conflicts

struct CometStorage {
    mapping(uint8 => address) comet;
    mapping(uint8 => address) base;
}

struct ManagementStorage {
    address chief;
    mapping(address => bool) isManager;
}

// for exact output multihop swaps
struct NumberCache {
    uint256 amount;
}

// for exact output multihop swaps
struct AddressCache {
    address cachedAddress;
}

// for flash loan validations and call targets
struct FlashLoanGatewayStorage {
    uint256 isOpen;
    mapping(address => bool) isValidTarget;
}

struct InitializerStorage {
    bool initialized;
}

library LibStorage {
    // Storage are structs where the data gets updated throughout the lifespan of the project
    bytes32 constant MARGIN_SWAP_STORAGE = keccak256("broker.storage.marginSwap");
    bytes32 constant COMET_STORAGE = keccak256("broker.storage.comet");
    bytes32 constant INITIALIZER = keccak256("broker.storage.initailizerStorage");
    bytes32 constant FLASH_LOAN_GATEWAY = keccak256("broker.storage.flashLoanGateway");
    bytes32 constant MANAGEMENT_STORAGE = keccak256("broker.storage.management");
    bytes32 constant NUMBER_CACHE = keccak256("1deltaAccount.storage.cache.number");
    bytes32 constant ADDRESS_CACHE = keccak256("1deltaAccount.storage.cache.address");

    function cometStorage() internal pure returns (CometStorage storage aas) {
        bytes32 position = COMET_STORAGE;
        assembly {
            aas.slot := position
        }
    }

    function managementStorage() internal pure returns (ManagementStorage storage ms) {
        bytes32 position = MANAGEMENT_STORAGE;
        assembly {
            ms.slot := position
        }
    }

    function flashLoanGatewayStorage() internal pure returns (FlashLoanGatewayStorage storage gs) {
        bytes32 position = FLASH_LOAN_GATEWAY;
        assembly {
            gs.slot := position
        }
    }

    function numberCacheStorage() internal pure returns (NumberCache storage ncs) {
        bytes32 position = NUMBER_CACHE;
        assembly {
            ncs.slot := position
        }
    }

    function addressCacheStorage() internal pure returns (AddressCache storage cs) {
        bytes32 position = ADDRESS_CACHE;
        assembly {
            cs.slot := position
        }
    }

    function initializerStorage() internal pure returns (InitializerStorage storage izs) {
        bytes32 position = INITIALIZER;
        assembly {
            izs.slot := position
        }
    }
}

/**
 * The `WithStorageComet` contract provides a base contract for Module contracts to inherit.
 */
abstract contract WithStorageComet {
    function cos() internal pure returns (CometStorage storage) {
        return LibStorage.cometStorage();
    }

    function ms() internal pure returns (ManagementStorage storage) {
        return LibStorage.managementStorage();
    }

    function ncs() internal pure returns (NumberCache storage) {
        return LibStorage.numberCacheStorage();
    }

    function acs() internal pure returns (AddressCache storage) {
        return LibStorage.addressCacheStorage();
    }

    function gs() internal pure returns (FlashLoanGatewayStorage storage) {
        return LibStorage.flashLoanGatewayStorage();
    }

    function izs() internal pure returns (InitializerStorage storage) {
        return LibStorage.initializerStorage();
    }
}
