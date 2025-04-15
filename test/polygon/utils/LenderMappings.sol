// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

library LenderMappingsPolygon {
    uint16 internal constant DEFAULT_LENDER = 1;
    uint16 internal constant AAVE_V3 = 0;
    uint16 internal constant AAVE_V2 = 1000;
    uint16 internal constant YLDR = 900;
    uint16 internal constant COMPOUND_V3_USDCE = 2000;

    uint16 internal constant MAX_AAVE_V2_ID = 2000;
    uint16 internal constant MAX_ID_COMPOUND_V3 = 3000;
    uint16 internal constant COMPOUND_V3_USDT = 2001;
}
