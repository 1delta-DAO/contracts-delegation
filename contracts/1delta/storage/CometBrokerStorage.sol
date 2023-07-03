// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

// We do not use an array of stucts to avoid pointer conflicts

// Management storage that stores the different DAO roles
struct TradeDataStorage {
    uint256 test;
}

struct CometStorage {
    mapping(uint8 => address) comet;
    mapping(uint8 => address) base;
}

struct CompoundStorage {
    address comptroller;
    mapping(address => address) cTokens;
}

struct UniswapStorage {
    address v3factory;
    address weth;
    address swapRouter;
}

struct DataProviderStorage {
    address dataProvider;
}

struct ManagementStorage {
    address chief;
    mapping(address => bool) isManager;
}

// for exact output multihop swaps
struct Cache {
    uint256 amount;
}

library LibStorage {
    // Storage are structs where the data gets updated throughout the lifespan of the project
    bytes32 constant DATA_PROVIDER_STORAGE = keccak256("broker.storage.dataProvider");
    bytes32 constant MARGIN_SWAP_STORAGE = keccak256("broker.storage.marginSwap");
    bytes32 constant UNISWAP_STORAGE = keccak256("broker.storage.uniswap");
    bytes32 constant COMET_STORAGE = keccak256("broker.storage.comet");
    bytes32 constant MANAGEMENT_STORAGE = keccak256("broker.storage.management");
    bytes32 constant CACHE = keccak256("broker.storage.cache");

    function dataProviderStorage() internal pure returns (DataProviderStorage storage ps) {
        bytes32 position = DATA_PROVIDER_STORAGE;
        assembly {
            ps.slot := position
        }
    }

    function cometStorage() internal pure returns (CometStorage storage aas) {
        bytes32 position = COMET_STORAGE;
        assembly {
            aas.slot := position
        }
    }

    function uniswapStorage() internal pure returns (UniswapStorage storage us) {
        bytes32 position = UNISWAP_STORAGE;
        assembly {
            us.slot := position
        }
    }

    function managementStorage() internal pure returns (ManagementStorage storage ms) {
        bytes32 position = MANAGEMENT_STORAGE;
        assembly {
            ms.slot := position
        }
    }

    function cacheStorage() internal pure returns (Cache storage cs) {
        bytes32 position = CACHE;
        assembly {
            cs.slot := position
        }
    }
}

/**
 * The `WithStorage` contract provides a base contract for Module contracts to inherit.
 *
 * It mainly provides internal helpers to access the storage structs, which reduces
 * calls like `LibStorage.treasuryStorage()` to just `ts()`.
 *
 * To understand why the storage stucts must be accessed using a function instead of a
 * state variable, please refer to the documentation above `LibStorage` in this file.
 */
abstract contract WithStorageComet {
    function ps() internal pure returns (DataProviderStorage storage) {
        return LibStorage.dataProviderStorage();
    }

    function cos() internal pure returns (CometStorage storage) {
        return LibStorage.cometStorage();
    }

    function us() internal pure returns (UniswapStorage storage) {
        return LibStorage.uniswapStorage();
    }

    function ms() internal pure returns (ManagementStorage storage) {
        return LibStorage.managementStorage();
    }

    function cs() internal pure returns (Cache storage) {
        return LibStorage.cacheStorage();
    }
}
