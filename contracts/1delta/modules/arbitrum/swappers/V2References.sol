// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

abstract contract V2ReferencesArbitrum {
    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    bytes32 internal constant UNI_V2_FF_FACTORY = 0xff5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f0000000000000000000000;
    bytes32 internal constant CODE_HASH_UNI_V2 = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 internal constant FRAX_SWAP_FF_FACTORY = 0xff8374A74A728f06bEa6B7259C68AA7BBB732bfeaD0000000000000000000000;
    bytes32 internal constant CODE_HASH_FRAX_SWAP = 0x46dd19aa7d926c9d41df47574e3c09b978a1572918da0e3da18ad785c1621d48;

    bytes32 internal constant SUSHI_V2_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
    bytes32 internal constant CODE_HASH_SUSHI_V2 = 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303;

    bytes32 internal constant CAMELOT_V2_FF_FACTORY = 0xff6EcCab422D763aC031210895C81787E87B43A6520000000000000000000000;
    bytes32 internal constant CODE_HASH_CAMELOT_V2 = 0xa856464ae65f7619087bc369daaf7e387dae1e5af69cfa7935850ebf754b04c1;

    bytes32 internal constant APESWAP_FF_FACTORY = 0xffCf083Be4164828f00cAE704EC15a36D7114912840000000000000000000000;
    bytes32 internal constant CODE_HASH_APESWAP = 0xae7373e804a043c4c08107a81def627eeb3792e211fb4711fcfe32f0e4c45fd5;

    address internal constant RAMSES_V1_FACTORY = 0xAA9B8a7430474119A442ef0C2Bf88f7c3c776F2F;
}
