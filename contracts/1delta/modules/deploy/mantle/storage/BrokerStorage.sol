// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;


struct GeneralLenderStorage {
    // map encoded uint8 + underlying address to lender tokens
    mapping(bytes32 => address) collateralTokens;
    mapping(bytes32 => address) debtTokens;
    mapping(bytes32 => address) stableDebtTokens;
    // map lender id to lender pool
    mapping(uint256 => address) lendingPools;
}

struct ManagementStorage {
    address chief;
    mapping(address => bool) isManager;
}

// allows storing anything into a bytes32
struct GeneralCache {
    bytes32 cache;
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
    bytes32 constant DATA_PROVIDER_STORAGE = keccak256("broker.storage.dataProvider");
    bytes32 constant MARGIN_SWAP_STORAGE = keccak256("broker.storage.marginSwap");
    bytes32 constant AAVE_STORAGE = keccak256("broker.storage.aave");
    bytes32 constant LENDER_STORAGE = keccak256("broker.storage.lender");
    bytes32 constant MANAGEMENT_STORAGE = keccak256("broker.storage.management");
    bytes32 constant FLASH_LOAN_GATEWAY = keccak256("broker.storage.flashLoanGateway");
    bytes32 constant INITIALIZER = keccak256("broker.storage.initailizerStorage");
    bytes32 constant NUMBER_CACHE = keccak256("broker.storage.cache.number");
    bytes32 constant ADDRESS_CACHE = keccak256("broker.storage.cache.address");
    bytes32 constant GENERAL_CACHE = keccak256("broker.storage.cache.general");


    function lenderStorage() internal pure returns (GeneralLenderStorage storage ls) {
        bytes32 position = LENDER_STORAGE;
        assembly {
            ls.slot := position
        }
    }

    function managementStorage() internal pure returns (ManagementStorage storage ms) {
        bytes32 position = MANAGEMENT_STORAGE;
        assembly {
            ms.slot := position
        }
    }

    function generalCacheStorage() internal pure returns (GeneralCache storage gcs) {
        bytes32 position = GENERAL_CACHE;
        assembly {
            gcs.slot := position
        }
    }

    function flashLoanGatewayStorage() internal pure returns (FlashLoanGatewayStorage storage gs) {
        bytes32 position = FLASH_LOAN_GATEWAY;
        assembly {
            gs.slot := position
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
 * The `WithStorage` contract provides a base contract for Module contracts to inherit.
 */
contract WithMantleStorage {
    function ls() internal pure returns (GeneralLenderStorage storage) {
        return LibStorage.lenderStorage();
    }

    function ms() internal pure returns (ManagementStorage storage) {
        return LibStorage.managementStorage();
    }

    function gs() internal pure returns (FlashLoanGatewayStorage storage) {
        return LibStorage.flashLoanGatewayStorage();
    }

    function gcs() internal pure returns (GeneralCache storage) {
        return LibStorage.generalCacheStorage();
    }

    function izs() internal pure returns (InitializerStorage storage) {
        return LibStorage.initializerStorage();
    }

    /** TOKEN GETTERS */

    function _getCollateralToken(address _underlying, uint8 _lenderId) internal view returns (address collateralToken) {
        mapping(bytes32 => address) storage collateralTokens = LibStorage.lenderStorage().collateralTokens;
        assembly {
            // Slot for collateralTokens[target] is keccak256(target . collateralTokens.slot).
            mstore(0x0, _underlying)
            mstore8(0x0, _lenderId)
            mstore(0x20, collateralTokens.slot)
            collateralToken := sload(keccak256(0x0, 0x40))
        }
    }

    function _getDebtToken(address _underlying, uint8 _lenderId) internal view returns (address debtToken) {
        mapping(bytes32 => address) storage debtTokens = LibStorage.lenderStorage().debtTokens;
        assembly {
            // Slot for debtTokens[target] is keccak256(target . debtTokens.slot).
            mstore(0x0, _underlying)
            mstore8(0x0, _lenderId)
            mstore(0x20, debtTokens.slot)
            debtToken := sload(keccak256(0x0, 0x40))
        }
    }

    function _getStableDebtToken(address _underlying, uint8 _lenderId) internal view returns (address stableDebtToken) {
        mapping(bytes32 => address) storage stableDebtTokens = LibStorage.lenderStorage().stableDebtTokens;
        assembly {
            // Slot for stableDebtTokens[target] is keccak256(target . stableDebtTokens.slot).
            mstore(0x0, _underlying)
            mstore8(0x0, _lenderId)
            mstore(0x20, stableDebtTokens.slot)
            stableDebtToken := sload(keccak256(0x0, 0x40))
        }
    }

    function _getLenderTokenKey(address _underlying, uint8 _lenderId) internal pure returns (bytes32 key) {
        assembly {
            mstore(0x0, _underlying)
            mstore8(0x0, _lenderId)
            key := mload(0x0)
        }
    }

    /** CACHING */

    function _cacheCaller() internal {
        bytes32 encoded;
        assembly {
            mstore(0x0, caller())
            encoded := mload(0x0)
        }
        gcs().cache = encoded;
    }
}