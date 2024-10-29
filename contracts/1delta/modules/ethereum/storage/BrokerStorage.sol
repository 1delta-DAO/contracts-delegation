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
    // typically used for lenders with multiple pools
    // like Compound V3 or Venus
    mapping(uint256 => address) lendingPools;
}

// allows storing anything into a bytes32
// typically used for transient storage variables
struct GeneralCache {
    bytes32 cache;
}

// storage for external calls 
struct ExternalCallStorage {
    // a validation apping that ensures that an external call can
    // be executed on an address
    // it is typically linked to an approval call
    mapping(address => mapping(address => bool)) isValidApproveAndCallTarget;
    // simple record that checks whether an address is ERC20-approved
    // will prevent external allowance call
    // typically used for curve style pools and dex aggregators
    mapping(address => mapping(address => bool)) isApproved;
}

// controls access to balancer-type flash loans
struct FlashLoanGateway {
    uint256 entryState;
}

library LibStorage {
    // this is the core diamond storage location
    bytes32 constant MODULE_STORAGE_POSITION = keccak256("diamond.standard.module.storage");
    // Storage are structs where the data gets updated throughout the lifespan of the project
    bytes32 constant LENDER_STORAGE = keccak256("broker.storage.lender");
    bytes32 constant GENERAL_CACHE = keccak256("broker.storage.cache.general");
    bytes32 constant EXTERNAL_CALL_STORAGE = keccak256("broker.storage.externalCalls");
    bytes32 constant FLASH_LOAN_GATEWAY = keccak256("broker.storage.flashLoanGateway");

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

    function moduleStorage() internal pure returns (LibModules.ModuleStorage storage ds) {
        bytes32 position = MODULE_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function flashLoanGatewayStorage() internal pure returns (FlashLoanGateway storage fgs) {
        bytes32 position = FLASH_LOAN_GATEWAY;
        assembly {
            fgs.slot := position
        }
    }
}

/**
 * The `WithStorage` contract provides a base contract for Module contracts to inherit.
 */
contract WithEthereumStorage {
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
