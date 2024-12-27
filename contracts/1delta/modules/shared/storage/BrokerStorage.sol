// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {LibModules} from "../../../proxy/libraries/LibModules.sol";

// We store lender data in the contract storage
// This is to avoid external contract calls to
// proxies to get certain addresses / references
struct GeneralLenderStorage {
    // map encoded uint8 + underlying address to lender tokens
    mapping(bytes32 => address) collateralTokens;
    mapping(bytes32 => address) debtTokens;
    mapping(bytes32 => address) stableDebtTokens;
    // map lender id to lender pool
    mapping(uint256 => address) lendingPools;
}

// allows storing anything into a bytes32
// typically used for transient storage variables
struct GeneralCache {
    bytes32 cache;
}

// a validation apping that ensures that an external call can
// be executed on an address
// it is typically linked to an approval call
struct ExternalCallStorage {
    mapping(address => mapping(address => bool)) isValidApproveAndCallTarget;
}

struct CallManagerStorage {
    mapping(address => bool) isValid;
    mapping(address => mapping(address => bool)) isApproved;
}

library LibStorage {
    // this is the core diamond storage location
    bytes32 constant MODULE_STORAGE_POSITION = keccak256("diamond.standard.module.storage");
    // Storage are structs where the data gets updated throughout the lifespan of the project
    bytes32 constant LENDER_STORAGE = keccak256("broker.storage.lender");
    bytes32 constant GENERAL_CACHE = keccak256("broker.storage.cache.general");
    bytes32 constant EXTERNAL_CALL_STORAGE = keccak256("broker.storage.externalCalls");
    bytes32 constant CALL_MANAGER_STORAGE = keccak256("broker.storage.callManager");

    function lenderStorage() internal pure returns (GeneralLenderStorage storage ls) {
        bytes32 position = LENDER_STORAGE;
        assembly {
            ls.slot := position
        }
    }

    function generalCacheStorage() internal pure returns (GeneralCache storage gcs) {
        bytes32 position = GENERAL_CACHE;
        assembly {
            gcs.slot := position
        }
    }

    function externalCallsStorage() internal pure returns (ExternalCallStorage storage es) {
        bytes32 position = EXTERNAL_CALL_STORAGE;
        assembly {
            es.slot := position
        }
    }

    function callManagerStorage() internal pure returns (CallManagerStorage storage es) {
        bytes32 position = CALL_MANAGER_STORAGE;
        assembly {
            es.slot := position
        }
    }

    function moduleStorage() internal pure returns (LibModules.ModuleStorage storage ds) {
        bytes32 position = MODULE_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}

/**
 * The `WithStorage` contract provides a base contract for Module contracts to inherit.
 */
contract WithBrokerStorage {
    function ls() internal pure returns (GeneralLenderStorage storage) {
        return LibStorage.lenderStorage();
    }

    function gcs() internal pure returns (GeneralCache storage) {
        return LibStorage.generalCacheStorage();
    }

    function es() internal pure returns (ExternalCallStorage storage) {
        return LibStorage.externalCallsStorage();
    }

    function ms() internal pure returns (LibModules.ModuleStorage storage) {
        return LibStorage.moduleStorage();
    }

    function cms() internal pure returns (CallManagerStorage storage) {
        return LibStorage.callManagerStorage();
    }

    /** TOKEN GETTERS */

    function _getLenderTokenKey(address _underlying, uint16 _lenderId) internal pure returns (bytes32 key) {
        assembly {
            key := or(shl(240, _lenderId), _underlying)
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
