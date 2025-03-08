// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {AaveLending} from "./AaveLending.sol";
import {CompoundV3Lending} from "./CompoundV3Lending.sol";
import {CompoundV2Lending} from "./CompoundV2Lending.sol";
import {MorphoLending} from "./MorphoLending.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * Lender classifier enums, expected to be encoded as uint16
 */
library LenderIds {
    uint256 internal constant UP_TO_AAVE_V3 = 1000;
    uint256 internal constant UP_TO_AAVE_V2 = 2000;
    uint256 internal constant UP_TO_COMPOUND_V3 = 3000;
    uint256 internal constant UP_TO_COMPOUND_V2 = 4000;
}

/**
 * Operations enums, encoded as uint8
 */
library LenderOps {
    uint256 internal constant DEPOSIT = 0;
    uint256 internal constant BORROW = 1;
    uint256 internal constant REPAY = 2;
    uint256 internal constant WITHDRAW = 3;
    uint256 internal constant DEPOSIT_LENDING_TOKEN = 4;
    uint256 internal constant WITHDRAW_LENDING_TOKEN = 5;
}

/**
 * @notice Merge all lending ops in one operation
 * Can inject parameters 
 * - paramPush for receiving funds (e.g. receiving funds from swaps or flash loans)
 * - paramPull for being required to pay an exact amount (e.g. DEX swap payments, flash loan amounts) 
 */
abstract contract UniversalLending is AaveLending, CompoundV3Lending, CompoundV2Lending, MorphoLending {
    /**
     * rexecute ANY lending operation across various lenders
     */
    function lendingOperations(
        address callerAddress,
        uint256 paramPull,
        uint256 paramPush,
        uint256 currentOffset // params similar to deltaComposeInternal
    ) internal returns (uint256) {
        uint256 lendingOperation;
        uint256 lender;
        assembly {
            let slice := calldataload(currentOffset)
            lendingOperation := shr(248, calldataload(currentOffset))
            lender := and(UINT16_MASK, shr(232, calldataload(currentOffset)))
            currentOffset := add(currentOffset, 3)
        }

        /** Deposit collateral */
        if (lendingOperation == LenderOps.DEPOSIT) {
            if (lender < LenderIds.UP_TO_AAVE_V3) {
                currentOffset = _depositToAaveV3(currentOffset, paramPush);
            } else if (lender < LenderIds.UP_TO_AAVE_V2) {
                currentOffset = _depositToAaveV2(currentOffset, paramPush);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                currentOffset = _depositToCompoundV3(currentOffset, paramPush);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                currentOffset = _depositToCompoundV2(currentOffset, paramPush);
            } else {
                currentOffset = _morphoDepositCollateral(currentOffset, callerAddress);
            }
        }
        /** Borrow */
        else if (lendingOperation == LenderOps.BORROW) {
            if (lender < LenderIds.UP_TO_AAVE_V2) {
                currentOffset = _borrowFromAave(currentOffset, callerAddress, paramPull);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                currentOffset = _borrowFromCompoundV3(currentOffset, callerAddress, paramPull);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                currentOffset = _borrowFromCompoundV2(currentOffset, callerAddress, paramPull);
            } else {
                currentOffset = _morphoBorrow(currentOffset, callerAddress);
            }
        }
        /** repay */
        else if (lendingOperation == LenderOps.REPAY) {
            if (lender < LenderIds.UP_TO_AAVE_V2) {
                currentOffset = _repayToAave(currentOffset, callerAddress, paramPull);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                currentOffset = _repayToCompoundV3(currentOffset, paramPush);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                currentOffset = _repayToCompoundV2(currentOffset, paramPush);
            } else {
                currentOffset = _morphoRepay(currentOffset, callerAddress);
            }
        }
        /** Morpho withdraw collateral */
        else if (lendingOperation == LenderOps.WITHDRAW) {
            if (lender < LenderIds.UP_TO_AAVE_V2) {
                currentOffset = _withdrawFromAave(currentOffset, callerAddress, paramPull);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V3) {
                currentOffset = _withdrawFromCompoundV3(currentOffset, callerAddress, paramPull);
            } else if (lender < LenderIds.UP_TO_COMPOUND_V2) {
                currentOffset = _withdrawFromCompoundV2(currentOffset, callerAddress, paramPull);
            } else {
                currentOffset = _morphoWithdrawCollateral(currentOffset, callerAddress);
            }
        }
        /** deposit lendingToken */
        else if (lendingOperation == LenderOps.DEPOSIT_LENDING_TOKEN) {
            currentOffset = _morphoDeposit(currentOffset, callerAddress);
        }
        /** withdraw lendingToken */
        else if (lendingOperation == LenderOps.WITHDRAW_LENDING_TOKEN) {
            currentOffset = _morphoWithdraw(currentOffset, callerAddress);
        } else revert();
        return currentOffset;
    }
}
