// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {DexMappingsTaiko} from "./DexMappings.sol";

interface IFactoryFeeGetter {
    function getFee(bool x) external view returns (uint256);

    function getPairFee(address y, bool x) external view returns (uint256);

    function stableFee() external view returns (uint256);

    function volatileFee() external view returns (uint256);

    function pairFee(address x) external view returns (uint256);

    function getFee(address x) external view returns (uint256);

    function stable() external view returns (bool);
}

contract AddressesTaiko {
    // users
    address internal testUser = 0xaaaa4a3F69b6DB76889bDfa4edBe1c0BB57BAA5c;

    /** DEX CONFIG */

    uint16 internal constant DEX_FEE_STABLES = 100;
    uint16 internal constant DEX_FEE_LOW_MEDIUM = 2500;
    uint16 internal constant DEX_FEE_LOW_HIGH = 3000;
    uint16 internal constant DEX_FEE_HIGHEST = 10000;
    uint16 internal constant DEX_FEE_LOW = 500;
    uint16 internal constant DEX_FEE_NONE = 0;

    uint16 internal constant KODO_VOLAT_FEE_DENOM = 10000 - 20;
    uint16 internal constant KODO_STABLE_FEE_DENOM = 10000 - 2;

    uint16 internal constant BASE_DENOM = 10000;

    function getV2PairFeeDenom(uint8 fork) internal pure returns (uint16) {
        if (fork == DexMappingsTaiko.KODO_VOLAT) return KODO_VOLAT_FEE_DENOM;
        return 0;
    }


    /** TRADE TYPE FLAG GETTERS */

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
