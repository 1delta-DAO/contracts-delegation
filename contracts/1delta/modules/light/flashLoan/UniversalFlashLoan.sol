// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {MorphoFlashLoans} from "./Morpho.sol";
import {AaveV2FlashLoans} from "./AaveV2.sol";
import {BalancerV2FlashLoans} from "./BalancerV2.sol";
import {AaveV3FlashLoans} from "./AaveV3.sol";
import {FlashLoanIds} from "../enums/DeltaEnums.sol";

/**
 * @title Flash loan aggregator
 * @author 1delta Labs AG
 */
contract UniversalFlashLoan is
    MorphoFlashLoans,
    AaveV2FlashLoans,
    AaveV3FlashLoans,
    BalancerV2FlashLoans //
{
    /**
     * All flash ones in one function -what do you need more?
     */
    function _universalFlashLoan(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        uint256 flashLoanType; // architecture type
        assembly {
            flashLoanType := shr(248, calldataload(currentOffset)) // already masks uint8 as last byte
            currentOffset := add(currentOffset, 1)
        }
        // for now we ignore MorphoB poolId
        if (flashLoanType == FlashLoanIds.MORPHO) {
            return morphoFlashLoan(currentOffset, callerAddress);
        } else if (flashLoanType == FlashLoanIds.BALANCER_V2) {
            return balancerV2FlashLoan(currentOffset, callerAddress);
        } else if (flashLoanType == FlashLoanIds.AAVE_V3) {
            return aaveV3FlashLoan(currentOffset, callerAddress);
        } else if (flashLoanType == FlashLoanIds.AAVE_V2) {
            return aaveV2FlashLoan(currentOffset, callerAddress);
        } else {
            _invalidOperation();
        }
    }
}
