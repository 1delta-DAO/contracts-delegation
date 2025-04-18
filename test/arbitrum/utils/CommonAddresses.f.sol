// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract AddressesArbitrum {
    // users
    address internal constant testUser = 0x5f6f935A9a69F886Dc0147904D0F455ABaC67e14;

    address internal constant WOO_POOL = 0xEd9e3f98bBed560e66B89AaC922E29D4596A9642;

    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    /**
     * DEX CONFIG
     */
    uint16 internal constant DEX_FEE_STABLES = 100;
    uint16 internal constant DEX_FEE_LOW_MEDIUM = 2500;
    uint16 internal constant DEX_FEE_LOW_HIGH = 3000;
    uint16 internal constant DEX_FEE_LOW = 500;
    uint16 internal constant DEX_FEE_NONE = 0;

    uint16 internal constant BIN_STEP_LOWEST = 1;
    uint16 internal constant BIN_STEP_LOW = 10;

    uint16 internal constant UNI_V2_FEE_DENOM = 10000 - 30;
    uint16 internal constant CAMELOT_V2_FEE_DENOM = 10000 - 30;
    uint16 internal constant SUSHI_V2_FEE_DENOM = 10000 - 30;
    uint16 internal constant APESWAP_FEE_DENOM = 10000 - 20;

    /**
     * TRADE TYPE FLAG GETTERS
     */
    function getOpenExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 2);
    }

    function getOpenExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 2);
    }

    function getCollateralSwapExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 3);
    }

    function getCollateralSwapExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 3);
    }

    function getCloseExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 3);
    }

    function getCloseExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 3);
    }

    function getDebtSwapExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 2);
    }

    function getDebtSwapExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 2);
    }
}
