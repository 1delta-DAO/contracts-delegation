// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

abstract contract V2ReferencesTaiko {
    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    bytes32 internal constant DTX_UNI_V2_FF_FACTORY = 0xff2ea9051d5a48ea2350b26306f2b959d262cf67e10000000000000000000000;
    // this one needs to be backchecked
    bytes32 internal constant CODE_HASH_DTX_UNI_V2 = 0x8615843ab28b4b86b2382dca22cf14f0a6ba9e52cb006531eb574042a5b54a46;

    bytes32 internal constant KODO_FF_FACTORY = 0xff535E02960574d8155596a73c7Ad66e87e37Eb6Bc0000000000000000000000;
    bytes32 constant KODO_CODE_HASH = 0x24364b5d47cc9af524ff2ae89d98c1c10f4a388556279eecb00622b5d727c99a;
}
