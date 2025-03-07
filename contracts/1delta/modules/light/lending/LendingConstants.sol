// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract LendingConstants {
    uint256 internal constant _PRE_PARAM = 1 << 127;
}
