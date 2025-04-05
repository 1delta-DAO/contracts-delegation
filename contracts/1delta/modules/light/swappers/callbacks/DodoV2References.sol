// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

/** 
 * Dodo has a registry mapping in their respective factory
 * By providing quote and base token together with the index in the array, the caller can validate the callback
 */
abstract contract DodoV2ReferencesBase {
    address internal constant DVM_FACTORY = 0x0226fCE8c969604C3A0AD19c37d1FAFac73e13c2;
}
