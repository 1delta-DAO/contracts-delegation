// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

// We do not use an array of stucts to avoid pointer conflicts

// Management storage that stores the different DAO roles
struct TradeDataStorage {
    uint256 test;
}

struct AAVEStorage {
    mapping(address => address) aTokens;
    mapping(address => address) vTokens;
    mapping(address => address) sTokens;
    address v3Pool;
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

// for fetching the amount that was calculated within a flash swap or flash loan
struct Cache {
    uint256 amount;
}

// for flash loan validations
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
    bytes32 constant UNISWAP_STORAGE = keccak256("broker.storage.uniswap");
    bytes32 constant AAVE_STORAGE = keccak256("broker.storage.aave");
    bytes32 constant MANAGEMENT_STORAGE = keccak256("broker.storage.management");
    bytes32 constant CACHE = keccak256("broker.storage.cache");
    bytes32 constant FLASH_LOAN_GATEWAY = keccak256("broker.storage.flashLoanGateway");
    bytes32 constant INITIALIZER = keccak256("broker.storage.initailizerStorage");

    function dataProviderStorage() internal pure returns (DataProviderStorage storage ps) {
        bytes32 position = DATA_PROVIDER_STORAGE;
        assembly {
            ps.slot := position
        }
    }

    function aaveStorage() internal pure returns (AAVEStorage storage aas) {
        bytes32 position = AAVE_STORAGE;
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
 *
 * It mainly provides internal helpers to access the storage structs, which reduces
 * calls like `LibStorage.treasuryStorage()` to just `ts()`.
 *
 * To understand why the storage stucts must be accessed using a function instead of a
 * state variable, please refer to the documentation above `LibStorage` in this file.
 */
contract WithStorage {
    function ps() internal pure returns (DataProviderStorage storage) {
        return LibStorage.dataProviderStorage();
    }

    function aas() internal pure returns (AAVEStorage storage) {
        return LibStorage.aaveStorage();
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

    function gs() internal pure returns (FlashLoanGatewayStorage storage) {
        return LibStorage.flashLoanGatewayStorage();
    }

    function izs() internal pure returns (InitializerStorage storage) {
        return LibStorage.initializerStorage();
    }
}
