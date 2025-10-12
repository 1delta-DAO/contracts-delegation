// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {EulerLending} from "./EulerLending.sol";
import {LenderIds, LenderOps} from "../enums/DeltaEnums.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";

/**
 * @notice Minimalistic lending operator to be used in external batchers like Euler's EVC
 * Can be safley used in forwarders as it does not rely on the caller address
 */
abstract contract SlimLending is EulerLending, DeltaErrors {
    /**
     * execute ANY lending operation across various lenders
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 1              | lendingOperation                |
     * | 1      | 2              | lender                          |
     * | 3      | variable       | rest                            |
     */
    function _lendingOperations(
        uint256 currentOffset // params similar to deltaComposeInternal
    )
        internal
        returns (uint256)
    {
        uint256 lendingOperation;
        uint256 lender;
        assembly {
            let slice := calldataload(currentOffset)
            lendingOperation := shr(248, slice)
            lender := and(UINT16_MASK, shr(232, slice))
            currentOffset := add(currentOffset, 3)
        }
        /**
         * Repay
         */
        if (lendingOperation == LenderOps.REPAY) {
            if (lender < LenderIds.UP_TO_EULER) {
                return _repayToEuler(currentOffset);
            }
        } else {
            _invalidOperation();
        }
    }
}
