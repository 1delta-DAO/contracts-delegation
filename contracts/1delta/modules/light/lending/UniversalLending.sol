// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {AaveLending} from "./AaveLending.sol";
import {CompoundV3Lending} from "./CompoundV3Lending.sol";
import {CompoundV2Lending} from "./CompoundV2Lending.sol";
import {MorphoLending} from "./MorphoLending.sol";
import {LenderIds, LenderOps} from "../enums/DeltaEnums.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Merge all lending ops in one operation
 * Can inject parameters
 * - paramPush for receiving funds (e.g. receiving funds from swaps or flash loans)
 * - paramPull for being required to pay an exact amount (e.g. DEX swap payments, flash loan amounts)
 */
abstract contract UniversalLending is AaveLending, CompoundV3Lending, CompoundV2Lending, MorphoLending {
    /**
     * execute ANY lending operation across various lenders
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 1              | lendingOperation                |
     * | 1      | 2              | lender                          |
     * | 3      | variable       | rest                            |
     */
    function _lendingOperations(
        address callerAddress,
        uint256 currentOffset // params similar to deltaComposeInternal
    ) internal returns (uint256) {
        uint256 lendingOperation;
        uint256 lender;
        assembly {
            let slice := calldataload(currentOffset)
            lendingOperation := shr(248, slice)
            lender := and(UINT16_MASK, shr(232, slice))
            currentOffset := add(currentOffset, 3)
        }
        /** Deposit collateral */
        if (lendingOperation == LenderOps.DEPOSIT) {
            if (lender < LenderIds.UP_TO_AAVE_V3) {
                return _depositToAaveV3(currentOffset);
            } else if (lender < LenderIds.UP_TO_AAVE_V2) {
                return _depositToAaveV2(currentOffset);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                return _depositToCompoundV3(currentOffset);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                return _depositToCompoundV2(currentOffset);
            } else {
                return _morphoDepositCollateral(currentOffset, callerAddress);
            }
        }
        /** Borrow */
        else if (lendingOperation == LenderOps.BORROW) {
            if (lender < LenderIds.UP_TO_AAVE_V2) {
                return _borrowFromAave(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                return _borrowFromCompoundV3(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                return _borrowFromCompoundV2(currentOffset, callerAddress);
            } else {
                return _morphoBorrow(currentOffset, callerAddress);
            }
        }
        /** Repay */
        else if (lendingOperation == LenderOps.REPAY) {
            if (lender < LenderIds.UP_TO_AAVE_V2) {
                return _repayToAave(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                return _repayToCompoundV3(currentOffset);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                return _repayToCompoundV2(currentOffset);
            } else {
                return _morphoRepay(currentOffset, callerAddress);
            }
        }
        /** Withdraw collateral */
        else if (lendingOperation == LenderOps.WITHDRAW) {
            if (lender < LenderIds.UP_TO_AAVE_V2) {
                return _withdrawFromAave(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                return _withdrawFromCompoundV3(currentOffset, callerAddress);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                return _withdrawFromCompoundV2(currentOffset, callerAddress);
            } else {
                return _morphoWithdrawCollateral(currentOffset, callerAddress);
            }
        }
        /** deposit lendingToken */
        else if (lendingOperation == LenderOps.DEPOSIT_LENDING_TOKEN) {
            return _morphoDeposit(currentOffset, callerAddress);
        }
        /** withdraw lendingToken */
        else if (lendingOperation == LenderOps.WITHDRAW_LENDING_TOKEN) {
            return _morphoWithdraw(currentOffset, callerAddress);
        } else revert();
    }
}
