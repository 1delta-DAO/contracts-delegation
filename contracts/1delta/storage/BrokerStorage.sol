// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

// We do not use an array of stucts to avoid pointer conflicts

struct AaveStorage {
    mapping(address => address) aTokens;
    mapping(address => address) vTokens;
    mapping(address => address) sTokens;
    address lendingPool;
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

struct OrderStorage {
    // How much taker token has been filled in order.
    // The lower `uint128` is the taker token fill amount.
    // The high bit will be `1` if the order was directly cancelled.
    mapping(bytes32 => uint256) orderHashToTakerTokenFilledAmount;
    // The minimum valid order salt for a given maker and order pair (maker, taker) for limit orders.
    // solhint-disable-next-line max-line-length
    mapping(address => mapping(address => mapping(address => uint256))) limitOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt;
    // The minimum valid order salt for a given maker and order pair (maker, taker) for RFQ orders.
    // solhint-disable-next-line max-line-length
    mapping(address => mapping(address => mapping(address => uint256))) rfqOrdersMakerToMakerTokenToTakerTokenToMinValidOrderSalt;
    // For a given order origin, which tx.origin addresses are allowed to fill the order.
    mapping(address => mapping(address => bool)) originRegistry;
    // For a given maker address, which addresses are allowed to
    // sign on its behalf.
    mapping(address => mapping(address => bool)) orderSignerRegistry;

    // tx origin => nonce buckets => min nonce
    mapping(address => mapping(uint64 => uint128)) txOriginNonces;
}

library LibStorage {
    // Storage are structs where the data gets updated throughout the lifespan of the project
    bytes32 constant DATA_PROVIDER_STORAGE = keccak256("broker.storage.dataProvider");
    bytes32 constant MARGIN_SWAP_STORAGE = keccak256("broker.storage.marginSwap");
    bytes32 constant AAVE_STORAGE = keccak256("broker.storage.aave");
    bytes32 constant MANAGEMENT_STORAGE = keccak256("broker.storage.management");
    bytes32 constant FLASH_LOAN_GATEWAY = keccak256("broker.storage.flashLoanGateway");
    bytes32 constant INITIALIZER = keccak256("broker.storage.initailizerStorage");
    bytes32 constant NUMBER_CACHE = keccak256("broker.storage.cache.number");
    bytes32 constant ADDRESS_CACHE = keccak256("broker.storage.cache.address");
    bytes32 constant ORDER_STORAGE = keccak256("broker.storage.orders");

    function aaveStorage() internal pure returns (AaveStorage storage aas) {
        bytes32 position = AAVE_STORAGE;
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

    function orderStorage() internal pure returns (OrderStorage storage os) {
        bytes32 position = ORDER_STORAGE;
        assembly {
            os.slot := position
        }
    }
}

/**
 * The `WithStorage` contract provides a base contract for Module contracts to inherit.
 */
contract WithStorage {

    function aas() internal pure returns (AaveStorage storage) {
        return LibStorage.aaveStorage();
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

    function os() internal pure returns (OrderStorage storage) {
        return LibStorage.orderStorage();
    }
}
