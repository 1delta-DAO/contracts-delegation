// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {MorphoFlashLoans} from "../../../flashLoan/Morpho.sol";

import {FlashLoanCallbacks} from "./FlashLoanCallbacks.sol";
import {FlashLoanIds} from "../../../enums/DeltaEnums.sol";
import {DeltaErrors} from "../../../../shared/errors/Errors.sol";

/**
 * @title Flash loan aggregator
 * @author 1delta Labs AG
 */
contract UniversalFlashLoan is
    MorphoFlashLoans,
    FlashLoanCallbacks //
{
    /**
     * All flash ones in one function -what do you need more?
     */
    function _universalFlashLoan(uint256 currentOffset, address callerAddress) internal virtual returns (uint256) {
        uint256 flashLoanType; // architecture type
        assembly {
            flashLoanType := shr(248, calldataload(currentOffset)) // already masks uint8 as last byte
            currentOffset := add(currentOffset, 1)
        }

        if (flashLoanType == FlashLoanIds.MORPHO) {
            return morphoFlashLoan(currentOffset, callerAddress);
        } else {
            _invalidOperation();
        }
    }
}
