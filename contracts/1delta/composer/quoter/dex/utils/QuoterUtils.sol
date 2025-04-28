// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

abstract contract QuoterUtils {
    /**
     * @notice Parse a revert reason returned from a swap call
     * @param reason Bytes reason from revert
     * @return value Extracted amount
     */
    function parseRevertReason(bytes memory reason) internal pure returns (uint256) {
        if (reason.length != 32) {
            if (reason.length != 64) revert("Unexpected error");
            // For iZi or other variants that return two values
            return abi.decode(reason, (uint256));
        }
        return abi.decode(reason, (uint256));
    }
}
