// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * Dodo has a registry mapping in their respective factory
 * By providing quote and base token together with the index in the array, the caller can validate the callback
 */
abstract contract DodoV2ReferencesBase {
    address internal constant DVM_FACTORY = 0x0226fCE8c969604C3A0AD19c37d1FAFac73e13c2;
    address internal constant DSP_FACTORY = 0x200D866Edf41070DE251Ef92715a6Ea825A5Eb80;
    address internal constant DPP_FACTORY = 0xc0F9553Df63De5a97Fe64422c8578D0657C360f7;
}
