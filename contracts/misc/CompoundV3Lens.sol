// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface IComet {
    function getSupplyRate(uint256 utilization) external view returns (uint64);

    function getBorrowRate(uint256 utilization) external view returns (uint64);

    function getUtilization() external view returns (uint256);
}

contract CompoundV3Lens {
    function getCometInterest(address comet) external view returns (uint256 borrowRate, uint256 supplyRate, uint256 utilization) {
        utilization = IComet(comet).getUtilization();
        supplyRate = IComet(comet).getSupplyRate(utilization);
        borrowRate = IComet(comet).getBorrowRate(utilization);
    }
}
