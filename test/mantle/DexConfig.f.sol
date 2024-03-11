// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract DexConfigMantle {
    uint24 internal DEX_FEE_STABLES = 100;
    uint24 internal DEX_FEE_LOW = 500;
    uint8 internal AGNI = 1;
    uint8 internal FUSION_X = 0;
    uint8 internal FUSION_X_V2 = 50;
    uint8 internal IZUMI = 100;

    function getOpenExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (6, 0, 2);
    }

    function getOpenExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 1, 2);
    }

    function getCloseExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (8, 0, 3);
    }

    function getCloseExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (5, 1, 3);
    }
}
