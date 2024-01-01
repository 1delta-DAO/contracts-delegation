// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.5.16;

import "../Comptroller/Comptroller.sol";

contract ComptrollerHarness is Comptroller {
    address xvsAddress;

    constructor(address xvsAddress_) public Comptroller() {
        xvsAddress = xvsAddress_;
    }

    function getXVSAddress() public view returns (address) {
        return xvsAddress;
    }

    function _setVenusRate(uint venusRate_) public {
        venusRate = venusRate_;
    }
    /**
     * @notice Set the amount of COMP distributed per block
     * @param compRate_ The amount of COMP wei per block to distribute
     */
    function harnessSetCompRate(uint compRate_) public {
        venusRate = compRate_;
    }

    function harnessAddCompMarkets(address[] memory cTokens) public {
        for (uint i; i < cTokens.length; i++) {
            // temporarily set compSpeed to 1 (will be fixed by `harnessRefreshCompSpeeds`)
            setVenusSpeedInternal(VToken(cTokens[i]), 1, 1);
        }
    }
}
